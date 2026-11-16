import 'dart:math' as math;

import 'track_path.dart';
import 'turntable_movement.dart';
import 'turntable_turn.dart';

/// Builds [TurntableTurn] instances for crossover platforms. Pure Dart.
abstract final class TurntableTurnBuilder {
  /// Builds all turns for one link: for `rotate`, includes both passes on
  /// self-crossings as well as forward/reversed entry and exit paths so the
  /// player can pick either perpendicular direction with arrow/WASD keys.
  static List<TurntableTurn> buildAll({
    required TrackPath from,
    required TrackPath to,
    required math.Point<double> center,
    double radius = 48,
    TurntableMovement movement = TurntableMovement.rotate,
  }) {
    if (movement == TurntableMovement.reverse) {
      return [
        TurntableTurn.build(
          from: from,
          to: to,
          center: center,
          radius: radius,
          movement: movement,
        ),
      ];
    }
    if (movement == TurntableMovement.slide) {
      return _buildSlideTurns(
        from: from,
        to: to,
        center: center,
        radius: radius,
      );
    }
    final fromHits = _hitsOrNearest(from, center);
    final toHits = _hitsOrNearest(to, center);
    final result = <TurntableTurn>[];
    for (final fh in fromHits) {
      for (final th in toHits) {
        if (identical(from, to) && (fh.along - th.along).abs() < 1.0) continue;
        result.addAll([
          _rotatePair(from, fh.along, to, th.along, center, radius),
          _rotatePair(
            from.reversed,
            from.length - fh.along,
            to,
            th.along,
            center,
            radius,
          ),
          _rotatePair(
            from,
            fh.along,
            to.reversed,
            to.length - th.along,
            center,
            radius,
          ),
          _rotatePair(
            from.reversed,
            from.length - fh.along,
            to.reversed,
            to.length - th.along,
            center,
            radius,
          ),
        ]);
      }
    }
    return result;
  }

  /// Returns `true` iff [from] and [to] have at least one pair of parallel,
  /// sideways-offset passes (`40..72 px` apart) near [center].
  static bool hasValidSlide(
    TrackPath from,
    TrackPath to,
    math.Point<double> center,
    double radius,
  ) => _slidePairs(from, to, center, radius).isNotEmpty;

  /// Returns `true` iff [path] has at least one pair of parallel, sideways-offset
  /// passes (`40..72 px` apart) near [center] for a same-loop slide.
  static bool hasValidSameLoopSlide(
    TrackPath path,
    math.Point<double> center,
    double radius,
  ) => hasValidSlide(path, path, center, radius);

  /// Wraps angle [a] in radians into `[-pi, pi)`.
  static double wrapPi(double a) {
    final wrapped = (a + math.pi) % (2 * math.pi);
    return wrapped - math.pi;
  }

  static List<TurntableTurn> _buildSlideTurns({
    required TrackPath from,
    required TrackPath to,
    required math.Point<double> center,
    required double radius,
  }) => [
    for (final pair in _slidePairs(from, to, center, radius)) ...[
      TurntableTurn.create(
        from: from,
        to: pair.sameDir ? to : to.reversed,
        center: center,
        radius: radius,
        fromAlong: pair.aAlong,
        toAlong: pair.sameDir ? pair.bAlong : to.length - pair.bAlong,
        movement: TurntableMovement.slide,
      ),
      TurntableTurn.create(
        from: from.reversed,
        to: pair.sameDir ? to.reversed : to,
        center: center,
        radius: radius,
        fromAlong: from.length - pair.aAlong,
        toAlong: pair.sameDir ? to.length - pair.bAlong : pair.bAlong,
        movement: TurntableMovement.slide,
      ),
    ],
  ];

  static Iterable<({double aAlong, double bAlong, bool sameDir})> _slidePairs(
    TrackPath from,
    TrackPath to,
    math.Point<double> center,
    double radius,
  ) sync* {
    final maxGap = math.max(radius, 64.0);
    final fromHits = from.crossingsNear(center, maxGap: maxGap);
    final toHits = to.crossingsNear(center, maxGap: maxGap);
    for (final a in fromHits) {
      for (final b in toHits) {
        final sameDir = _slidePairSameDir(from, a.along, to, b.along);
        if (sameDir != null) {
          yield (aAlong: a.along, bAlong: b.along, sameDir: sameDir);
        }
      }
    }
  }

  static bool? _slidePairSameDir(
    TrackPath from,
    double aAlong,
    TrackPath to,
    double bAlong,
  ) {
    if (identical(from, to) && (aAlong - bAlong).abs() < 1.0) return null;
    final ha = from.headingAt(aAlong);
    final hb = to.headingAt(bAlong);
    final angleDiff = wrapPi(ha - hb).abs();
    if (angleDiff > 0.2 && (angleDiff - math.pi).abs() > 0.2) return null;
    final pa = from.positionAt(aAlong);
    final pb = to.positionAt(bAlong);
    final dist = pa.distanceTo(pb);
    if (dist < 40.0 || dist > 72.0) return null;
    final alongDot =
        (math.sin(ha) * (pb.x - pa.x) - math.cos(ha) * (pb.y - pa.y)).abs() /
        dist;
    if (alongDot > 0.2) return null;
    return angleDiff < math.pi / 2;
  }

  static List<({double along, double gap})> _hitsOrNearest(
    TrackPath path,
    math.Point<double> center,
  ) {
    final hits = path.crossingsNear(center);
    return hits.isNotEmpty ? hits : [path.nearest(center)];
  }

  static TurntableTurn _rotatePair(
    TrackPath from,
    double fromAlong,
    TrackPath to,
    double toAlong,
    math.Point<double> center,
    double radius,
  ) => TurntableTurn.create(
    from: from,
    to: to,
    center: center,
    radius: radius,
    fromAlong: fromAlong,
    toAlong: toAlong,
    movement: TurntableMovement.rotate,
  );
}
