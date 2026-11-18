import 'dart:ui';

import 'package:flame/components.dart';

import '../systems/track_graph.dart';
import 'pixel_art.dart';

const Radius _hullRadius = Radius.circular(4);

/// Draws a tram hull with drop shadow, optional pixel-art [sprite], surface
/// wreck / crash cross, or river submersion ripple matching `TramComponent`.
void paintTramHull(
  Canvas canvas, {
  required Vector2 size,
  required Color color,
  Sprite? sprite,
  required bool isCrashed,
  required TrackEnd? crashHazard,
  required double sinkProgress,
}) {
  final hull = size.toRect();
  final hullRRect = RRect.fromRectAndRadius(hull, _hullRadius);
  if (crashHazard != TrackEnd.river) {
    canvas.drawRRect(
      hullRRect.shift(const Offset(3, 4)),
      Paint()..color = const Color(0x50000000),
    );
  }
  _paintBody(canvas, size, hullRRect, color, sprite, isCrashed, crashHazard);
  if (crashHazard == TrackEnd.river) {
    _paintRiverSubmersion(canvas, size, hull, hullRRect, sinkProgress);
  } else if (isCrashed) {
    _paintCrashCross(canvas, size);
  }
}

void _paintBody(
  Canvas canvas,
  Vector2 size,
  RRect hullRRect,
  Color color,
  Sprite? sprite,
  bool isCrashed,
  TrackEnd? crashHazard,
) {
  if (sprite != null) {
    sprite.render(canvas, size: size, overridePaint: pixelArtPaint());
    return;
  }
  final isSurfaceWreck = isCrashed && crashHazard != TrackEnd.river;
  canvas.drawRRect(
    hullRRect,
    Paint()..color = isSurfaceWreck ? const Color(0xFF3A3E48) : color,
  );
  if (!isCrashed) {
    canvas.drawRect(
      Rect.fromLTWH(2, 2, size.x - 4, 10),
      Paint()..color = const Color(0xFFF3E9D2),
    );
  }
}

void _paintRiverSubmersion(
  Canvas canvas,
  Vector2 size,
  Rect hull,
  RRect hullRRect,
  double sinkProgress,
) {
  final waterTint = const Color(0xFF061426)
      .withValues(alpha: 0.72 * sinkProgress);
  canvas.drawRRect(hullRRect, Paint()..color = waterTint);
  if (sinkProgress < 1.0) {
    final expand = 18 * sinkProgress;
    final ripple = Rect.fromCenter(
      center: hull.center,
      width: size.x + expand,
      height: size.y + expand,
    );
    canvas.drawOval(
      ripple,
      Paint()
        ..color = const Color(0xFF78ECFF)
            .withValues(alpha: 0.8 * (1.0 - sinkProgress))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  } else {
    _paintCrashCross(canvas, size);
  }
}

void _paintCrashCross(Canvas canvas, Vector2 size) {
  final crossPaint = Paint()
    ..color = const Color(0xFFFF5A36)
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  canvas
    ..drawLine(const Offset(3, 4), Offset(size.x - 3, size.y - 4), crossPaint)
    ..drawLine(Offset(size.x - 3, 4), Offset(3, size.y - 4), crossPaint);
}
