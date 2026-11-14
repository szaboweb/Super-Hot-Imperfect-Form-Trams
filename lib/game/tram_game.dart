import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';

import '../core/game_log.dart';
import 'components/atmosphere_component.dart';
import 'components/building_component.dart';
import 'components/crossover_component.dart';
import 'components/depth_component.dart';
import 'components/ground_component.dart';
import 'components/headlight_component.dart';
import 'components/hud_component.dart';
import 'components/overhead_wire_component.dart';
import 'components/signal_component.dart';
import 'components/slide_rail_component.dart';
import 'components/turntable_disc_component.dart';
import 'components/turntable_rail_component.dart';
import 'components/track_component.dart';
import 'components/tram_component.dart';
import 'components/y_rail_component.dart';
import 'levels/crossover_data.dart';
import 'levels/level_data.dart';
import 'levels/level_repository.dart';
import 'levels/prop_data.dart';
import 'systems/turntable_movement.dart';
import 'systems/turntable_turn.dart';
import 'systems/track_path.dart';
import 'systems/turntable_switch_system.dart';

/// Root Flame game: loads [initialLevel] (or the first asset level) and builds
/// the world layer by layer (see `RenderLayer`): depth, ground, track,
/// entities, canopy, atmosphere + HUD.
class TramGame extends FlameGame with HasKeyboardHandlerComponents {
  TramGame({this.initialLevel});

  final LevelData? initialLevel;

  /// All trams of the loaded level, in spawn order.
  final List<TramComponent> trams = [];

  /// Whole level visible at once (switch-flipping needs the overview).
  static final Vector2 visibleSize = Vector2(960, 640);

  late final LevelData _level;
  late final Map<String, TrackPath> _paths;
  late final GroundComponent _ground;
  final List<({CrossoverData data, List<TurntableTurn> turns})> _crossovers =
      [];

  Vector2 get _bounds => Vector2(_level.width, _level.height);

  @override
  Color backgroundColor() => const Color(0xFF05080F);

  @override
  Future<void> onLoad() async {
    await _loadLevel();
    await _buildDepthAndGround();
    await _buildTrack();
    await _spawnTrams();
    await _buildCrossovers();
    await _buildCanopy();
    await _buildAtmosphereAndHud();
    camera.viewfinder
      ..visibleGameSize = visibleSize
      ..position = Vector2.zero();
  }

  Future<void> _loadLevel() async {
    _level = initialLevel ?? (await LevelRepository().loadAll()).first;
    GameLog.event(
      'level',
      '${_level.id}: ${_level.spawns.length} trams, '
          '${_level.crossovers.length} crossovers',
    );
    _paths = {
      for (final s in _level.segments)
        if (s.points.length >= 2) s.id: TrackPath(s.points, name: s.id),
    };
    for (final data in _level.crossovers) {
      _crossovers.add((
        data: data,
        turns: [
          for (final l in data.links)
            TurntableTurn.build(
              from: _paths[l.from]!,
              to: _paths[l.to]!,
              center: data.center,
              radius: data.radius,
              movement: data.movement,
            ),
        ],
      ));
    }
  }

  // 1. depth  2. ground
  Future<void> _buildDepthAndGround() async {
    _ground = GroundComponent(
      bounds: _bounds,
      channels: [
        for (final p in _level.props.where((p) => p.type == PropType.channel))
          Rect.fromCenter(
            center: Offset(p.x, p.y),
            width: p.width,
            height: p.height,
          ),
      ],
      paths: _paths.values.toList(),
    );
    await world.addAll([DepthComponent(), _ground]);
  }

  // 3. rails of the loops and decorative signals
  Future<void> _buildTrack() async {
    await world.addAll([
      for (final path in _paths.values) TrackComponent(path: path),
    ]);
    for (final p in _level.props.where((p) => p.type == PropType.signal)) {
      await world.add(
        SignalComponent(
          position: Vector2(p.x, p.y),
          rotationDeg: p.rotationDeg,
          green: p.state != 'red',
        ),
      );
    }
  }

  // 4. entities: every spawn of the level becomes a tram (spawn `time` not scheduled yet)
  Future<void> _spawnTrams() async {
    trams.clear();
    for (final spawn in _level.spawns) {
      final path = _paths[spawn.segment];
      if (path == null) {
        throw StateError('Spawn segment "${spawn.segment}" has no geometry');
      }
      trams.add(
        TramComponent(
          path: path,
          speed: spawn.speed,
          controls: spawn.controls,
          trackDistance: spawn.startDistance,
          color: Color(spawn.color),
        )..onSkid = _ground.addSkidMark,
      );
    }
    await world.addAll(trams);
  }

  // 2./3. turntable discs (below the rails), L-rails and switch lights; they need the trams
  Future<void> _buildCrossovers() async {
    final allTurns = [for (final c in _crossovers) ...c.turns];
    final switches = TurntableSwitchSystem(allTurns);
    for (final tram in trams) {
      tram.switches = switches;
    }
    for (final c in _crossovers) {
      final crossover = CrossoverComponent(
        data: c.data,
        turns: c.turns,
        trams: trams,
      );
      await world.addAll([
        crossover,
        TurntableDiscComponent(crossover: crossover),
        _railFor(crossover),
      ]);
    }
  }

  /// The rails that move with a platform, by how it carries the tram.
  TrackComponent _railFor(CrossoverComponent crossover) =>
      switch (crossover.data.movement) {
        TurntableMovement.rotate => TurntableRailComponent(
          crossover: crossover,
        ),
        TurntableMovement.slide => SlideRailComponent(crossover: crossover),
        TurntableMovement.reverse => YRailComponent(crossover: crossover),
      };

  // 5. canopy
  Future<void> _buildCanopy() async {
    await world.addAll([
      for (final p in _level.props.where((p) => p.type == PropType.building))
        BuildingComponent(
          position: Vector2(p.x, p.y),
          size: Vector2(p.width, p.height),
          angle: p.rotationDeg * math.pi / 180,
        ),
      for (final path in _paths.values) OverheadWireComponent(path: path),
    ]);
  }

  // 6. atmosphere  7. HUD (screen space)
  Future<void> _buildAtmosphereAndHud() async {
    await world.addAll([
      AtmosphereComponent(bounds: _bounds),
      for (final tram in trams) HeadlightComponent(tram: tram),
    ]);
    await camera.viewport.add(
      HudComponent(trams: trams, paths: _paths.values.toList()),
    );
  }
}
