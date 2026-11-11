import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';

import 'components/atmosphere_component.dart';
import 'components/building_component.dart';
import 'components/depth_component.dart';
import 'components/ground_component.dart';
import 'components/headlight_component.dart';
import 'components/hud_component.dart';
import 'components/overhead_wire_component.dart';
import 'components/signal_component.dart';
import 'components/track_component.dart';
import 'components/tram_component.dart';
import 'levels/level_repository.dart';
import 'levels/prop_data.dart';
import 'systems/track_path.dart';

/// Root Flame game: loads the first level and builds the world layer by layer
/// (see `RenderLayer`): depth, ground, track, entities, canopy, atmosphere + HUD.
class TramGame extends FlameGame with HasKeyboardHandlerComponents {
  late final TramComponent player;

  /// Whole level visible at once (switch-flipping needs the overview).
  static final Vector2 visibleSize = Vector2(960, 640);

  @override
  Color backgroundColor() => const Color(0xFF05080F);

  @override
  Future<void> onLoad() async {
    final level = (await LevelRepository().loadAll()).first;
    final paths = {
      for (final s in level.segments)
        if (s.points.length >= 2) s.id: TrackPath(s.points),
    };
    final props = level.props;
    final bounds = Vector2(level.width, level.height);

    // 1. depth  2. ground
    final ground = GroundComponent(
      bounds: bounds,
      channels: [
        for (final p in props.where((p) => p.type == PropType.channel))
          Rect.fromCenter(
            center: Offset(p.x, p.y),
            width: p.width,
            height: p.height,
          ),
      ],
      paths: paths.values.toList(),
    );
    await world.addAll([DepthComponent(), ground]);

    // 3. track and signals
    for (final path in paths.values) {
      await world.add(TrackComponent(path: path));
    }
    for (final p in props.where((p) => p.type == PropType.signal)) {
      await world.add(
        SignalComponent(
          position: Vector2(p.x, p.y),
          rotationDeg: p.rotationDeg,
          green: p.state != 'red',
        ),
      );
    }

    // 4. entities
    final spawn = level.spawns.first;
    final spawnPath = paths[spawn.segment];
    if (spawnPath == null) {
      throw StateError('Spawn segment "${spawn.segment}" has no geometry');
    }
    player = TramComponent(path: spawnPath, speed: spawn.speed)
      ..onSkid = ground.addSkidMark;
    await world.add(player);

    // 5. canopy
    for (final p in props.where((p) => p.type == PropType.building)) {
      await world.add(
        BuildingComponent(
          position: Vector2(p.x, p.y),
          size: Vector2(p.width, p.height),
          angle: p.rotationDeg * math.pi / 180,
        ),
      );
    }
    for (final path in paths.values) {
      await world.add(OverheadWireComponent(path: path));
    }

    // 6. atmosphere
    await world.addAll([
      AtmosphereComponent(bounds: bounds),
      HeadlightComponent(tram: player),
    ]);

    // 7. HUD (screen space)
    await camera.viewport.add(
      HudComponent(tram: player, paths: paths.values.toList()),
    );

    camera.viewfinder
      ..visibleGameSize = visibleSize
      ..position = Vector2.zero();
  }
}
