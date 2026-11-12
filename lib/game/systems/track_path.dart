import 'dart:math' as math;

/// Polyline in world px that vehicles follow. Pure Dart (no Flame), so it is unit-testable.
///
/// Headings use the game convention: angle 0 = pointing up (-y), clockwise positive.
/// A path whose first and last points coincide is closed and wraps around.
class TrackPath {
  TrackPath(List<math.Point<double>> points, {this.name = ''})
    : assert(points.length >= 2, 'a path needs at least two points'),
      points = List.unmodifiable(points),
      _cumulative = _cumulativeLengths(points);

  /// Segment id (or `from->to` for a crossover connector); used in log lines.
  final String name;
  final List<math.Point<double>> points;
  final List<double> _cumulative;

  double get length => _cumulative.last;

  bool get isClosed => points.first.distanceTo(points.last) < 0.001;

  math.Point<double> positionAt(double distance) {
    final d = normalize(distance);
    var i = 1;
    while (i < _cumulative.length - 1 && _cumulative[i] < d) {
      i++;
    }
    final segLength = _cumulative[i] - _cumulative[i - 1];
    final t = segLength == 0 ? 0.0 : (d - _cumulative[i - 1]) / segLength;
    final a = points[i - 1];
    final b = points[i];
    return math.Point(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
  }

  /// Smoothed heading: direction between points slightly behind and ahead,
  /// so the sprite doesn't snap at polyline vertices.
  double headingAt(double distance, {double lookAround = 6}) {
    final from = positionAt(distance - lookAround);
    final to = positionAt(distance + lookAround);
    return math.atan2(to.x - from.x, -(to.y - from.y));
  }

  /// Path distance (and how far off the path it is) of the polyline point nearest to [p].
  ({double along, double gap}) nearest(math.Point<double> p) {
    var bestAlong = 0.0;
    var bestGap = double.infinity;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final dx = points[i].x - a.x;
      final dy = points[i].y - a.y;
      final lengthSquared = dx * dx + dy * dy;
      final t = lengthSquared == 0
          ? 0.0
          : (((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared).clamp(
              0.0,
              1.0,
            );
      final gap = p.distanceTo(math.Point(a.x + dx * t, a.y + dy * t));
      if (gap < bestGap) {
        bestGap = gap;
        bestAlong = _cumulative[i - 1] + math.sqrt(lengthSquared) * t;
      }
    }
    return (along: bestAlong, gap: bestGap);
  }

  /// Wraps [distance] into the path (closed) or clamps it to its ends (open).
  double normalize(double distance) {
    if (isClosed) return distance % length;
    return distance.clamp(0.0, length);
  }

  static List<double> _cumulativeLengths(List<math.Point<double>> points) {
    final result = <double>[0];
    for (var i = 1; i < points.length; i++) {
      result.add(result.last + points[i - 1].distanceTo(points[i]));
    }
    return result;
  }
}
