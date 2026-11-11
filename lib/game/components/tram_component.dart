import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import '../graphics/pixel_art.dart';
import '../graphics/render_layer.dart';
import '../systems/track_path.dart';

/// Layer 4 (entities): tram that rides a [TrackPath]; drawn from a pixel-art
/// [sprite] (Blender render cleaned up in Aseprite) or, when none is set, with Canvas shapes.
class TramComponent extends PositionComponent with KeyboardHandler {
  TramComponent({
    required this.path,
    this.sprite,
    this.trackDistance = 0,
    this.speed = 0,
  }) : super(
         size: Vector2(20, 56),
         anchor: Anchor.center,
         priority: RenderLayer.entities.priority,
       ) {
    _snapToPath();
  }

  final TrackPath path;
  Sprite? sprite;

  static const double maxSpeed = 320;
  static const double acceleration = 220;
  static const double drag = 0.8;

  /// Minimum |speed| (px/s) at which braking leaves skid marks.
  static const double skidMinSpeed = 60;

  /// -1 (brake/reverse) .. 1 (accelerate)
  double throttle = 0;

  /// Signed speed along the path in px/s.
  double speed;

  /// Distance travelled along [path] in px.
  double trackDistance;

  /// 0 (cool) .. 1 (overheated); rises while braking hard.
  double brakeHeat = 0;

  /// Called every frame the tram is skidding (braking while moving).
  void Function(Vector2 position, double angle)? onSkid;

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    final up =
        keysPressed.contains(LogicalKeyboardKey.arrowUp) ||
        keysPressed.contains(LogicalKeyboardKey.keyW);
    final down =
        keysPressed.contains(LogicalKeyboardKey.arrowDown) ||
        keysPressed.contains(LogicalKeyboardKey.keyS);
    throttle = (up ? 1.0 : 0.0) - (down ? 1.0 : 0.0);
    return true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final braking = throttle * speed < 0 && speed.abs() > skidMinSpeed;
    brakeHeat = (brakeHeat + (braking ? 0.4 : -0.15) * dt).clamp(0.0, 1.0);
    speed += throttle * acceleration * dt;
    speed *= math.pow(drag, dt).toDouble();
    speed = speed.clamp(-maxSpeed / 3, maxSpeed);
    trackDistance += speed * dt;
    _snapToPath();
    if (braking) onSkid?.call(position, angle);
  }

  void _snapToPath() {
    final p = path.positionAt(trackDistance);
    position.setValues(p.x, p.y);
    angle = path.headingAt(trackDistance);
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
