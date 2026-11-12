import 'dart:math' as math;

import 'track_path.dart';
import 'turntable_ride.dart';

/// A turntable at the point where loop [from] crosses loop [to]: a tram on [from]
/// that is on the disc can have it rotate by [sweep] so it continues on [to].
/// Pure Dart (no Flame).
class TurntableTurn {
  TurntableTurn({
    required this.from,
    required this.to,
    required this.center,
    required this.radius,
    required this.fromAlong,
    required this.toAlong,
    required this.fromHeading,
    required this.sweep,
  });

  factory TurntableTurn.build({
    required TrackPath from,
    required TrackPath to,
    required math.Point<double> center,
    double radius = 48,
  }) {
    final fromAlong = from.nearest(center).along;
    final toAlong = to.nearest(center).along;
    final fromHeading = from.headingAt(fromAlong);
    final toHeading = to.headingAt(toAlong);
    return TurntableTurn(
      from: from,
      to: to,
      center: center,
      radius: radius,
      fromAlong: fromAlong,
      toAlong: toAlong,
      fromHeading: fromHeading,
      sweep: _wrapPi(toHeading - fromHeading),
    );
  }

  /// The disc never turns faster than this, even if the tram is about to leave it
  /// (it then rides the still-turning disc a little past the edge).
  static const double minRideSeconds = 0.1;
  static const double maxRideSeconds = 0.6;

  final TrackPath from;
  final TrackPath to;
  final math.Point<double> center;
  final double radius;

  /// Where the crossing lies along [from] and [to] (px along each path).
  final double fromAlong;
  final double toAlong;

  /// Heading of [from] at the crossing.
  final double fromHeading;

  /// Signed rotation (rad): positive = clockwise (right turn), negative = left turn.
  final double sweep;

  /// Signed px of a tram at [distance] on [path] from the crossing, along [from]'s
  /// direction of travel (negative = still approaching); null if [path] is not [from].
  double? offsetOf(TrackPath path, double distance) {
    if (!identical(path, from)) return null;
    final offset = distance - fromAlong;
    if (!from.isClosed) return offset;
    final half = from.length / 2;
    return ((offset + half) % from.length) - half;
  }

  /// Starts a ride if any part of the tram (centre at [distance] on [path], moving
  /// [speed] px/s) is on the disc: nose or tail within the radius. The disc turns as fast
  /// as needed to finish while the tram is on it, within [minRideSeconds]..[maxRideSeconds].
  /// Null if the tram is off the disc, stopped, or on another loop.
  TurntableRide? board(
    TrackPath path,
    double distance,
    double speed,
    double halfLength,
  ) {
    final offset = offsetOf(path, distance);
    if (offset == null || speed <= 0) return null;
    final reach = radius + halfLength;
    if (offset < -reach || offset > reach) return null;
    final seconds = (reach - offset) / speed;
    return TurntableRide(
      turn: this,
      offset: offset,
      duration: seconds.clamp(minRideSeconds, maxRideSeconds),
      halfLength: halfLength,
    );
  }

  static double _wrapPi(double a) {
    final wrapped = (a + math.pi) % (2 * math.pi);
    return wrapped - math.pi;
  }
}
