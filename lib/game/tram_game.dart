import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';

import 'components/tram.dart';

class TramGame extends FlameGame with HasKeyboardHandlerComponents {
  late final Tram player;

  @override
  Color backgroundColor() => const Color(0xFF1B1B24);

  @override
  Future<void> onLoad() async {
    // Top-down view: the camera follows the player tram.
    player = Tram()..position = Vector2.zero();
    await world.add(player);
    camera.follow(player);
  }
}
