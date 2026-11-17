import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../graphics/render_layer.dart';

/// Layer 5 (canopy): short-lived electric blue pantograph spark burst on SHIFT switches.
class SparkEffectComponent extends PositionComponent {
  /// Creates a one-shot spark burst centred at world [position].
  SparkEffectComponent({required Vector2 position})
    : super(
        position: position,
        anchor: Anchor.center,
        priority: RenderLayer.canopy.priority + 2,
      );

  /// Lifetime of the spark burst in seconds.
  static const double durationSec = 0.32;

  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= durationSec) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / durationSec).clamp(0.0, 1.0);
    final fade = 1.0 - t;
    if (fade <= 0) return;

    canvas.drawCircle(
      Offset.zero,
      5.5 * fade,
      Paint()
        ..color = Color.fromARGB((210 * fade).round(), 0xE0, 0xFC, 0xFF)
        ..blendMode = BlendMode.plus,
    );

    final cyanPaint = Paint()
      ..color = Color.fromARGB((225 * fade).round(), 0x64, 0xF4, 0xFF)
      ..blendMode = BlendMode.plus
      ..strokeWidth = 2.2 * fade + 0.4
      ..strokeCap = StrokeCap.round;
    final corePaint = Paint()
      ..color = Color.fromARGB((240 * fade).round(), 0xFF, 0xFF, 0xFF)
      ..blendMode = BlendMode.plus
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 12; i++) {
      final rayAngle = i * math.pi / 6 + (i.isEven ? 0.18 : -0.11);
      final reach = i.isEven ? 24.0 : 17.0;
      final dir = Offset(math.cos(rayAngle), math.sin(rayAngle));
      final inner = dir * (reach * 0.25 * t);
      final outer = dir * (reach * (0.35 + 0.65 * t));
      final mid = Offset.lerp(inner, outer, 0.55)!;
      canvas
        ..drawLine(inner, outer, cyanPaint)
        ..drawLine(inner, mid, corePaint);
    }
  }
}
