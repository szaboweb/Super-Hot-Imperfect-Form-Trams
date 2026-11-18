import 'dart:math' as math;

import 'track_path.dart';

/// Tight-radius quarter-circle turnout rails of a wye platform, in entry-aligned
/// platform coordinates (origin = switch centre, entry heading = up = -y).
///
/// The tram enters along `(0, entry) -> (0, radius)` and curves smoothly over
/// [radius] onto the left (`sweep < 0`) or right (`sweep >= 0`) perpendicular branch
/// at `(±radius, 0)`. Pure Dart so it is unit-testable.
TrackPath curveTurnPath({
  required double radius,
  required double entry,
  required double sweep,
}) {
  const arcSteps = 12;
  final sideSign = sweep >= 0 ? 1.0 : -1.0;
  final points = <math.Point<double>>[
    if (entry > radius) math.Point<double>(0, entry),
    math.Point<double>(0, radius),
    for (var i = 1; i <= arcSteps; i++)
      math.Point<double>(
        sideSign * radius * (1 - math.cos(i * (math.pi / 2) / arcSteps)),
        radius * (1 - math.sin(i * (math.pi / 2) / arcSteps)),
      ),
  ];
  return TrackPath(points, name: 'wye_turn');
}
