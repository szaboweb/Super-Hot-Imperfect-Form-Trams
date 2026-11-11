import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';

import 'components/track_component.dart';
import 'components/tram_component.dart';
import 'levels/level_repository.dart';
import 'systems/track_path.dart';

/// Root Flame game: loads the first level and puts the player's tram on its track.
class TramGame extends FlameGame with HasKeyboardHandlerComponents {
  late final TramComponent player;

  /// Whole level visible at once (switch-flipping needs the overview).
  static final Vector2 visibleSize = Vector2(960, 640);

  @override
  Color backgroundColor() => const Color(0xFF1B1B24);

  @override
  Future<void> onLoad() async {
    final level = (await LevelRepository().loadAll()).first;
    final paths = {
      for (final s in level.segments)
        if (s.points.length >= 2) s.id: TrackPath(s.points),
    };
    for (final path in paths.values) {
      await world.add(TrackComponent(path: path));
    }

    final spawn = level.spawns.first;
    final spawnPath = paths[spawn.segment];
    if (spawnPath == null) {
      throw StateError('Spawn segment "${spawn.segment}" has no geometry');
    }
    player = TramComponent(path: spawnPath, speed: spawn.speed);
    await world.add(player);

    camera.viewfinder
      ..visibleGameSize = visibleSize
      ..position = Vector2.zero();
  }
}
