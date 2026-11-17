import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../graphics/render_layer.dart';
import '../systems/track_graph.dart';

/// Layer 4 (entities): one-shot impact shockwave, debris burst, or river splash on crash.
class CrashEffectComponent extends PositionComponent {
  /// Creates a crash burst at world [position] styled for [hazard].
  CrashEffectComponent({required Vector2 position, this.hazard})
    : super(
        position: position,
        anchor: Anchor.center,
        priority: RenderLayer.entities.priority + 50,
      );

  /// Hazard that ended the tram's run, or `null` for a tram-vs-tram collision.
  final TrackEnd? hazard;

  /// Total duration of the burst animation in seconds.
  static const double durationSec = 0.5;

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
    if (hazard == TrackEnd.river) {
      _renderRiverSplash(canvas, t, fade);
    } else {
      _renderImpactBurst(canvas, t, fade);
    }
  }

  void _renderRiverSplash(Canvas canvas, double t, double fade) {
    canvas
      ..drawCircle(
        Offset.zero,
        8 + 30 * t,
        Paint()
          ..color = Color.fromARGB((210 * fade).round(), 0x5C, 0xE1, 0xE6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * fade + 0.4,
      )
      ..drawCircle(
        Offset.zero,
        4 + 18 * t,
        Paint()
          ..color = Color.fromARGB((230 * fade).round(), 0xFF, 0xFF, 0xFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 * fade + 0.3,
      );
    final dropPaint = Paint()
      ..color = Color.fromARGB((220 * fade).round(), 0xBD, 0xF4, 0xFF);
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5 + 0.15;
      final dist = (14.0 + (i.isEven ? 12.0 : 6.0)) * t;
      canvas.drawCircle(
        Offset(math.cos(a) * dist, math.sin(a) * dist),
        2.2 * fade + 0.4,
        dropPaint,
      );
    }
  }

  void _renderImpactBurst(Canvas canvas, double t, double fade) {
    canvas
      ..drawCircle(
        Offset.zero,
        9 * fade,
        Paint()
          ..color = Color.fromARGB((220 * fade).round(), 0xFF, 0xD1, 0x66)
          ..blendMode = BlendMode.plus,
      )
      ..drawCircle(
        Offset.zero,
        6 + 32 * t,
        Paint()
          ..color = Color.fromARGB((220 * fade).round(), 0xFF, 0x6B, 0x35)
          ..blendMode = BlendMode.plus
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2 * fade + 0.5,
      );
    final shardPaint = Paint()
      ..color = Color.fromARGB((235 * fade).round(), 0xFF, 0xB6, 0x27)
      ..strokeWidth = 2.0 * fade + 0.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5 + (i.isEven ? 0.12 : -0.09);
      final dir = Offset(math.cos(a), math.sin(a));
      final inner = dir * (10.0 * t);
      final outer = dir * ((22.0 + (i.isEven ? 10.0 : 4.0)) * t);
      canvas.drawLine(inner, outer, shardPaint);
    }
  }
}
