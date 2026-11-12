import 'package:flutter/services.dart';

/// Keyboard layout that drives one tram (see `controls` of a spawn in the level JSON).
enum TramControls {
  /// Arrow keys (right SHIFT flips the switch).
  arrows(
    accelerate: LogicalKeyboardKey.arrowUp,
    brake: LogicalKeyboardKey.arrowDown,
    switchKey: LogicalKeyboardKey.shiftRight,
  ),

  /// W / S keys (left SHIFT flips the switch).
  wasd(
    accelerate: LogicalKeyboardKey.keyW,
    brake: LogicalKeyboardKey.keyS,
    switchKey: LogicalKeyboardKey.shiftLeft,
  );

  const TramControls({
    required this.accelerate,
    required this.brake,
    required this.switchKey,
  });

  final LogicalKeyboardKey accelerate;
  final LogicalKeyboardKey brake;

  /// Key that flips this player's crossover switch.
  final LogicalKeyboardKey switchKey;

  /// -1 (brake/reverse) .. 1 (accelerate) for the currently pressed keys.
  double throttleFor(Set<LogicalKeyboardKey> keysPressed) {
    final up = keysPressed.contains(accelerate) ? 1.0 : 0.0;
    final down = keysPressed.contains(brake) ? 1.0 : 0.0;
    return up - down;
  }

  /// Short label for the HUD.
  String get label => this == arrows ? 'ARROWS' : 'W/S';

  /// HUD name of [switchKey].
  String get switchLabel => this == arrows ? 'R-SHIFT' : 'L-SHIFT';
}
