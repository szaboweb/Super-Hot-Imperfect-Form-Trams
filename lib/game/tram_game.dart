import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;

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
import 'systems/crash_system.dart';
import 'systems/score_system.dart';
import 'systems/spawn_system.dart';
import 'systems/turntable_movement.dart';
import 'systems/turntable_turn.dart';
import 'systems/turntable_turn_builder.dart';
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

  /// Notifies UI widgets when the level crash goal is first satisfied.
  final ValueNotifier<bool> goalMetNotifier = ValueNotifier<bool>(false);

  /// Minimum viewport extent in world px so small levels are not zoomed too close.
  static final Vector2 visibleSize = Vector2(1040, 680);

  late final LevelData _level;
  late final Map<String, TrackPath> _paths;
  late final GroundComponent _ground;
  late final SpawnSystem _spawnSystem;
  late final CrashSystem _crashSystem;
  late final ScoreSystem _scoreSystem;
  late final TurntableSwitchSystem _switches;
  final List<({CrossoverData data, List<TurntableTurn> turns})> _crossovers =
      [];

  /// Score and crash-goal state for the active level.
  ScoreSystem get scoreSystem => _scoreSystem;

  /// Camera visible size covering at least [visibleSize] and the loaded level bounds.
  Vector2 get effectiveVisibleSize => Vector2(
    math.max(visibleSize.x, _level.width),
    math.max(visibleSize.y, _level.height),
  );

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
      ..visibleGameSize = effectiveVisibleSize
      ..position = Vector2.zero();
  }

  @override
  void onRemove() {
    goalMetNotifier.dispose();
    super.onRemove();
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
            ...TurntableTurnBuilder.buildAll(
              from: _paths[l.from]!,
              to: _paths[l.to]!,
              center: data.center,
              radius: data.radius,
              movement: data.movement,
            ),
        ],
      ));
    }
    _switches = TurntableSwitchSystem([
      for (final c in _crossovers) ...c.turns,
    ]);
    _spawnSystem = SpawnSystem(_level.spawns);
    _scoreSystem = ScoreSystem(crashGoal: _level.crashGoal);
    _crashSystem = CrashSystem(graph: _level.buildGraph(), paths: _paths);
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
      for (final p in _level.props.where((p) => p.type == PropType.signal))
        SignalComponent(
          position: Vector2(p.x, p.y),
          rotationDeg: p.rotationDeg,
          green: p.state != 'red',
        ),
    ]);
  }

  // 4. entities: spawns due at t = 0 enter now; delayed spawns enter in update(dt).
  Future<void> _spawnTrams() async {
    trams.clear();
    for (final spawn in _spawnSystem.advance(0)) {
      trams.add(_createTram(spawn));
    }
    if (trams.isNotEmpty) await world.addAll(trams);
  }

  TramComponent _createTram(SpawnData spawn) {
    final path = _paths[spawn.segment];
    if (path == null) {
      throw StateError('Spawn segment "${spawn.segment}" has no geometry');
    }
    return TramComponent(
        path: path,
        speed: spawn.speed,
        controls: spawn.controls,
        trackDistance: spawn.startDistance,
        color: Color(spawn.color),
      )
      ..switches = _switches
      ..occupiedPlatformCenters = _occupiedPlatformCenters
      ..onSkid = _ground.addSkidMark;
  }

  Iterable<math.Point<double>> _occupiedPlatformCenters() => [
    for (final other in trams)
      if (other.ride != null) other.ride!.turn.center,
  ];

  // 2./3. turntable discs (below the rails), L-rails and switch lights; they need the trams
  Future<void> _buildCrossovers() async {
    for (final c in _crossovers) {
      final cx = CrossoverComponent(data: c.data, turns: c.turns, trams: trams);
      await world.addAll([
        cx,
        TurntableDiscComponent(crossover: cx),
        _railFor(cx),
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
      HudComponent(
        trams: trams,
        paths: _paths.values.toList(),
        score: _scoreSystem,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (final spawn in _spawnSystem.advance(dt)) {
      final tram = _createTram(spawn);
      trams.add(tram);
      world.addAll([tram, HeadlightComponent(tram: tram)]);
      GameLog.event(
        'tram',
        '${tram.label} spawned at t=${_spawnSystem.elapsedSeconds.toStringAsFixed(2)}s',
      );
    }
    if (trams.isEmpty) return;
    _stepCrashes();
  }

  void _stepCrashes() {
    final result = _crashSystem.step([
      for (final (i, tram) in trams.indexed)
        (
          index: i,
          label: tram.label,
          segmentId: tram.path.name,
          trackDistance: tram.trackDistance,
          speed: tram.speed,
          position: math.Point(tram.position.x, tram.position.y),
          heading: tram.angle,
          isRidingTurntable: tram.ride != null,
          isCrashed: tram.isCrashed,
        ),
    ]);
    for (final t in result.transitions) {
      final tram = trams[t.tramIndex];
      tram.path = t.nextPath;
      tram.trackDistance = t.nextDistance;
      final p = t.nextPath.positionAt(t.nextDistance);
      tram.position.setValues(p.x, p.y);
      tram.angle = t.nextPath.headingAt(t.nextDistance);
    }
    for (final event in result.crashes) {
      for (final idx in event.tramIndices) {
        trams[idx].markCrashed();
      }
      GameLog.event('crash', event.description);
      if (!_scoreSystem.record(event)) continue;
      goalMetNotifier.value = true;
      GameLog.event(
        'level',
        'Goal reached: ${_scoreSystem.crashCount}/${_scoreSystem.crashGoal} crashes',
      );
    }
  }
}
