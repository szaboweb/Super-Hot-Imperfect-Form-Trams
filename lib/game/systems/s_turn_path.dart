import 'dart:math' as math;

import 'track_path.dart';

/// Smooth S-curve turnout path in entry-aligned platform coordinates
/// (origin = switch stem point on the entry lane, entry heading = up = -y).
///
/// Runs straight along `(0, entry) -> (0, curveHalfSpan)` then follows a smooth
/// S-curve to `(slideDistance, -curveHalfSpan)` and finishes with a short
/// tangent straight tail to `(slideDistance, -halfSpan)` so exit headings align
/// cleanly with the parallel branch rail. Pure Dart.
TrackPath sTurnPath({
  required double slideDistance,
  required double entry,
  double halfSpan = 32.0,
}) {
  const steps = 24;
  const straightTail = 6.0;
  final curveSpan = math.max(8.0, halfSpan - straightTail);
  final points = <math.Point<double>>[
    if (entry > curveSpan) math.Point<double>(0, entry),
    math.Point<double>(0, curveSpan),
    for (var i = 1; i <= steps; i++)
      _sCurvePoint(slideDistance, curveSpan, i / steps),
    math.Point<double>(slideDistance, -halfSpan),
  ];
  return TrackPath(points, name: 's_turn');
}

math.Point<double> _sCurvePoint(
  double slideDistance,
  double curveSpan,
  double t,
) {
  final ease = 0.5 * (1 - math.cos(math.pi * t));
  return math.Point<double>(
    slideDistance * ease,
    curveSpan - 2 * curveSpan * t,
  );
}
