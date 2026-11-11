import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import '../graphics/pixel_art.dart';

/// Tram drawn either from a pixel-art [sprite] (Blender render cleaned up in
/// Aseprite, see docs/ASSET_PIPELINE.md) or, when none is set, with Canvas shapes.
class TramComponent extends PositionComponent with KeyboardHandler {
  TramComponent({this.sprite})
    : super(size: Vector2(24, 64), anchor: Anchor.center);

  Sprite? sprite;

  static const double maxSpeed = 320;
  static const double acceleration = 220;
  static const double drag = 0.8;
  static const double turnRate = 2.4; // rad/s at full speed

  /// -1 (left) .. 1 (right)
  double steer = 0;

  /// -1 (brake/reverse) .. 1 (accelerate)
  double throttle = 0;

  double speed = 0;

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    final left =
        keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA);
    final right =
        keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD);
    final up =
        keysPressed.contains(LogicalKeyboardKey.arrowUp) ||
        keysPressed.contains(LogicalKeyboardKey.keyW);
    final down =
        keysPressed.contains(LogicalKeyboardKey.arrowDown) ||
        keysPressed.contains(LogicalKeyboardKey.keyS);
    steer = (right ? 1.0 : 0.0) - (left ? 1.0 : 0.0);
    throttle = (up ? 1.0 : 0.0) - (down ? 1.0 : 0.0);
    return true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    speed += throttle * acceleration * dt;
    speed *= math.pow(drag, dt).toDouble();
    speed = speed.clamp(-maxSpeed / 3, maxSpeed);

    angle += steer * turnRate * (speed / maxSpeed) * dt;
    // Tram's nose points up at angle 0.
    position += Vector2(math.sin(angle), -math.cos(angle)) * speed * dt;
  }

  @override
  void render(Canvas canvas) {
    final sprite = this.sprite;
    if (sprite != null) {
      sprite.render(canvas, size: size, overridePaint: pixelArtPaint());
      return;
    }
    // Canvas fallback: used until pixel-art textures exist.
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(4)),
      Paint()..color = const Color(0xFFE4572E),
    );
    canvas.drawRect(
      Rect.fromLTWH(2, 2, size.x - 4, 10),
      Paint()..color = const Color(0xFFF3E9D2),
    );
  }
}
