import 'dart:math' as math;

import 'track_path.dart';
import 'turntable_movement.dart';
import 'turntable_ride.dart';
import 'turntable_turn_builder.dart';

/// A crossover platform at the point where loop [from] meets loop [to]: a tram on [from]
/// that is on the platform can have it carry the tram on to [to], moving as [movement]
/// says: rotate by [sweep], slide sideways by [slide], reverse via Y-turn onto `from.reversed`,
/// or curve onto a perpendicular branch. Pure Dart (no Flame).
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
    this.movement = TurntableMovement.rotate,
    this.fromPoint = const math.Point(0, 0),
    this.slide = const math.Point(0, 0),
  });

  /// [movement] decides the geometry: `rotate` turns from [from]'s heading to [to]'s,
  /// `slide` moves sideways from [from]'s lane to the parallel lane of [to], `reverse`
  /// ignores [to] and uses `from.reversed`.
  factory TurntableTurn.build({
    required TrackPath from,
    required TrackPath to,
    required math.Point<double> center,
    double radius = 48,
    TurntableMovement movement = TurntableMovement.rotate,
  }) {
    final exit = movement == TurntableMovement.reverse ? from.reversed : to;
    return TurntableTurn.create(
      from: from,
      to: exit,
      center: center,
      radius: radius,
      fromAlong: from.nearest(center).along,
      toAlong: exit.nearest(center).along,
      movement: movement,
    );
  }

  /// Constructs a [TurntableTurn] from precomputed [fromAlong] and [toAlong]
  /// crossing positions.
  factory TurntableTurn.create({
    required TrackPath from,
    required TrackPath to,
    required math.Point<double> center,
    required double radius,
    required double fromAlong,
    required double toAlong,
    required TurntableMovement movement,
  }) {
    final fromHeading = from.headingAt(fromAlong);
    final fromPoint = from.positionAt(fromAlong);
    return TurntableTurn(
      from: from,
      to: to,
      center: center,
      radius: radius,
      fromAlong: fromAlong,
      toAlong: toAlong,
      fromHeading: fromHeading,
      sweep: switch (movement) {
        TurntableMovement.rotate || TurntableMovement.curve =>
          TurntableTurnBuilder.wrapPi(to.headingAt(toAlong) - fromHeading),
        TurntableMovement.slide => 0,
        TurntableMovement.reverse => math.pi,
      },
      movement: movement,
      fromPoint: fromPoint,
      slide: movement == TurntableMovement.slide
          ? to.positionAt(toAlong) - fromPoint
          : const math.Point(0, 0),
    );
  }

  /// Forwards to [TurntableTurnBuilder.buildAll].
  static List<TurntableTurn> buildAll({
    required TrackPath from,
    required TrackPath to,
    required math.Point<double> center,
    double radius = 48,
    TurntableMovement movement = TurntableMovement.rotate,
  }) => TurntableTurnBuilder.buildAll(
    from: from,
    to: to,
    center: center,
    radius: radius,
    movement: movement,
  );

  /// The platform never moves faster than this, even if the tram is about to leave it
  /// (it then rides the still-moving platform a little past the edge).
  static const double minRideSeconds = 0.2;
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
  /// 0 for a slide, pi for a reverse.
  final double sweep;

  final TurntableMovement movement;

  /// Point of [from] at the crossing (the lane a sliding platform starts on).
  final math.Point<double> fromPoint;

  /// Sideways move of a sliding platform from [from]'s lane to [to]'s lane (px).
  final math.Point<double> slide;

  /// Lane distance of a slide, px.
  double get slideDistance => slide.distanceTo(const math.Point(0, 0));

  /// Distance along [path] of the crossing; null if [path] is not served by this turn.
  /// A reverse turn serves its loop in both directions.
  double? alongOn(TrackPath path) {
    if (identical(path, from)) return fromAlong;
    if (movement == TurntableMovement.reverse && identical(path, to)) {
      return toAlong;
    }
    return null;
  }

  /// Signed px of a tram at [distance] on [path] from the crossing, along [path]'s
  /// direction of travel (negative = still approaching); null if this turn does not serve [path].
  double? offsetOf(TrackPath path, double distance) {
    final along = alongOn(path);
    if (along == null) return null;
    final offset = distance - along;
    if (!path.isClosed) return offset;
    final half = path.length / 2;
    return ((offset + half) % path.length) - half;
  }

  /// Starts a ride if any part of the tram (centre at [distance] on [path], moving
  /// [speed] px/s, positive forward or negative in reverse gear) is on the platform:
  /// nose or tail within the radius. A rotating or sliding platform moves as fast as
  /// needed to finish while the tram is on it, within [minRideSeconds]..[maxRideSeconds].
  /// Null if the tram is off the platform, stopped, or on another loop.
  TurntableRide? board(
    TrackPath path,
    double distance,
    double speed,
    double halfLength,
  ) {
    final offset = offsetOf(path, distance);
    if (offset == null || speed == 0) return null;
    final travelSign = speed < 0 ? -1.0 : 1.0;
    final signedOffset = offset * travelSign;
    final reach = radius + halfLength;
    final maxOffset = movement == TurntableMovement.curve ? 12.0 : reach;
    if (signedOffset < -reach || signedOffset > maxOffset) return null;
    final seconds = (reach - signedOffset) / speed.abs();
    return TurntableRide(
      turn: this,
      entry: path,
      offset: offset,
      duration: seconds.clamp(minRideSeconds, maxRideSeconds),
      halfLength: halfLength,
      travelSign: travelSign,
    );
  }
}
