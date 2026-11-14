import 'dart:math' as math;
import 'dart:ui';

import '../levels/crossover_data.dart';

/// Canvas outline of a crossover platform of [shape] around the origin, [radius] px big.
/// A rectangle is as long as the disc is wide, along the rails (x axis), and tall enough
/// to cover two lanes [lanePitch] px apart.
Path platformShapePath(
  PlatformShape shape,
  double radius, {
  double lanePitch = 60,
}) {
  return switch (shape) {
    PlatformShape.circle =>
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: radius)),
    PlatformShape.rectangle =>
      Path()..addRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 2,
          height: lanePitch + 40,
        ),
      ),
    PlatformShape.square =>
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: radius * 2,
            height: radius * 2,
          ),
          const Radius.circular(4),
        ),
      ),
    PlatformShape.triangle => _trianglePath(radius * 1.15),
  };
}

Path _trianglePath(double reach) {
  final path = Path();
  for (var i = 0; i < 3; i++) {
    final a = i * 2 * math.pi / 3 - math.pi / 2;
    final p = Offset(math.cos(a) * reach, math.sin(a) * reach);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}
