import 'dart:math' as math;

import 'track_path.dart';

/// Y-shaped reversing rails of a triangle platform, in platform coordinates
/// (heading up = -y, x to the right): a stem from [entry] px behind the centre up to the
/// fork at the origin, then two arms that run forward and are joined by a 180 degree arc.
/// A tram driving this path leaves along the stem again, now facing the other way.
/// [radius] scales the Y (48 = default platform). Pure Dart.
TrackPath yTurnPath({required double radius, required double entry}) {
  final scale = radius / 48;
  final armLength = 14 * scale;
  final spread = 16 * scale;
  final points = <math.Point<double>>[
    math.Point(0, entry),
    ..._arm(armLength, -spread, forward: true),
    ..._arc(2 * armLength, spread),
    ..._arm(armLength, spread, forward: false),
    math.Point(0, entry),
  ];
  return TrackPath(points, name: 'y_turn');
}

/// Platform point at [along] px ahead of the fork and [side] px to the right.
math.Point<double> _at(double along, double side) => math.Point(side, -along);

/// S-bend between the fork and the arc start, following a cubic with horizontal tangents.
List<math.Point<double>> _arm(
  double length,
  double side, {
  required bool forward,
}) {
  const steps = 8;
  final result = <math.Point<double>>[];
  for (var i = 0; i <= steps; i++) {
    final t = i / steps;
    final u = 1 - t;
    final b1 = 3 * u * u * t;
    final b2 = 3 * u * t * t;
    final b3 = t * t * t;
    final along = (b1 + 2 * b2 + 3 * b3) * length;
    final across = (b2 + b3) * side;
    result.add(_at(along, across));
  }
  return forward ? result : result.reversed.toList();
}

/// Half circle of [radius] around the point [centerAlong] px ahead of the fork,
/// from the left arm (side -radius) over the far point to the right arm.
List<math.Point<double>> _arc(double centerAlong, double radius) {
  const steps = 12;
  return [
    for (var i = 1; i < steps; i++)
      _at(
        centerAlong + radius * math.sin(i * math.pi / steps),
        -radius * math.cos(i * math.pi / steps),
      ),
  ];
}
