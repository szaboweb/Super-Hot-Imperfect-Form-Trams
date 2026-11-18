import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Keyboard layout that drives one tram (see `controls` of a spawn in the level JSON).
enum TramControls {
  /// Arrow keys (right SHIFT flips the switch).
  arrows(
    accelerate: LogicalKeyboardKey.arrowUp,
    brake: LogicalKeyboardKey.arrowDown,
    turnLeft: LogicalKeyboardKey.arrowLeft,
    turnRight: LogicalKeyboardKey.arrowRight,
    switchKey: LogicalKeyboardKey.shiftRight,
  ),

  /// W / S keys (left SHIFT flips the switch).
  wasd(
    accelerate: LogicalKeyboardKey.keyW,
    brake: LogicalKeyboardKey.keyS,
    turnLeft: LogicalKeyboardKey.keyA,
    turnRight: LogicalKeyboardKey.keyD,
    switchKey: LogicalKeyboardKey.shiftLeft,
  );

  const TramControls({
    required this.accelerate,
    required this.brake,
    required this.turnLeft,
    required this.turnRight,
    required this.switchKey,
  });

  final LogicalKeyboardKey accelerate;
  final LogicalKeyboardKey brake;
  final LogicalKeyboardKey turnLeft;
  final LogicalKeyboardKey turnRight;

  /// Key that flips this player's crossover switch.
  final LogicalKeyboardKey switchKey;

  /// -1 (brake/reverse) .. 1 (accelerate) for the currently pressed keys.
  double throttleFor(Set<LogicalKeyboardKey> keysPressed) {
    final up = keysPressed.contains(accelerate) ? 1.0 : 0.0;
    final down = keysPressed.contains(brake) ? 1.0 : 0.0;
    return up - down;
  }

  /// Horizontal turn steering: -1 (left), 0 (none), +1 (right) independent of throttle.
  double turnSteerFor(Set<LogicalKeyboardKey> keysPressed) =>
      (keysPressed.contains(turnRight) ? 1.0 : 0.0) -
      (keysPressed.contains(turnLeft) ? 1.0 : 0.0);

  /// Screen-space unit vector for the held directional keys, or null if none.
  math.Point<double>? desiredDirectionFor(Set<LogicalKeyboardKey> keysPressed) {
    final dx =
        (keysPressed.contains(turnRight) ? 1.0 : 0.0) -
        (keysPressed.contains(turnLeft) ? 1.0 : 0.0);
    final dy =
        (keysPressed.contains(brake) ? 1.0 : 0.0) -
        (keysPressed.contains(accelerate) ? 1.0 : 0.0);
    if (dx == 0 && dy == 0) return null;
    final len = math.sqrt(dx * dx + dy * dy);
    return math.Point(dx / len, dy / len);
  }

  /// Short label for the HUD.
  String get label => this == arrows ? 'ARROWS' : 'W/S';

  /// HUD name of [switchKey].
  String get switchLabel => this == arrows ? 'R-SHIFT' : 'L-SHIFT';
}
