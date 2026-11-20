import 'dart:math' as math;

import 'track_path.dart';
import 'turntable_movement.dart';
import 'turntable_turn.dart';

/// Candidate parallel lane pair for an S-curve parallel-lane Y-switch (`turnout`).
typedef SlideLanePair = ({double aAlong, double bAlong, bool sameDir});

/// Builds and validates S-curve parallel-lane Y-switch
/// ([TurntableMovement.turnout]) turns from parallel same-direction lane pairs.
/// Pure Dart.
abstract final class TurnoutTurnBuilder {
  /// Emits diverging (SHIFT) and converging (auto-board) turns for [from] -> [to].
  static List<TurntableTurn> buildAll({
    required TrackPath from,
    required TrackPath to,
    required math.Point<double> center,
    required double radius,
    required Iterable<SlideLanePair> pairs,
    math.Point<double>? stemPoint,
    math.Point<double>? forward,
  }) {
    final fwd = _normalized(forward);
    final result = <TurntableTurn>[];
    for (final p in pairs) {
      final aPos = from.positionAt(p.aAlong);
      if (stemPoint != null && aPos.distanceTo(stemPoint) >= 8.0) continue;
      final bAligned = p.sameDir ? to : to.reversed;
      final bAlong = p.sameDir ? p.bAlong : to.length - p.bAlong;
      final oriented = _orientedPairs(from, p.aAlong, bAligned, bAlong, fwd);
      for (final o in oriented) {
        _addTurnoutSet(o.a, o.aAlong, o.b, o.bAlong, center, radius, result);
      }
    }
    return result;
  }

  /// Returns `true` iff at least one valid turnout set can be constructed.
  static bool hasValidTurnout({
    required TrackPath from,
    required TrackPath to,
    required math.Point<double> center,
    required double radius,
    required Iterable<SlideLanePair> pairs,
    math.Point<double>? stemPoint,
    math.Point<double>? forward,
  }) => buildAll(
    from: from,
    to: to,
    center: center,
    radius: radius,
    pairs: pairs,
    stemPoint: stemPoint,
    forward: forward,
  ).isNotEmpty;

  static List<({TrackPath a, double aAlong, TrackPath b, double bAlong})>
  _orientedPairs(
    TrackPath a,
    double aAlong,
    TrackPath b,
    double bAlong,
    math.Point<double>? fwd,
  ) {
    final candidates = [
      (a: a, aAlong: aAlong, b: b, bAlong: bAlong),
      if (fwd != null)
        (
          a: a.reversed,
          aAlong: a.length - aAlong,
          b: b.reversed,
          bAlong: b.length - bAlong,
        ),
    ];
    if (fwd == null) return candidates;
    return [
      for (final c in candidates)
        if (_dotHeading(c.a, c.aAlong, fwd) > 0.7) c,
    ];
  }

  static double _dotHeading(
    TrackPath path,
    double along,
    math.Point<double> dir,
  ) {
    final h = path.headingAt(along);
    return math.sin(h) * dir.x - math.cos(h) * dir.y;
  }

  static math.Point<double>? _normalized(math.Point<double>? v) {
    if (v == null) return null;
    final len = v.distanceTo(const math.Point(0, 0));
    return len > 1e-6 ? math.Point(v.x / len, v.y / len) : null;
  }

  static void _addTurnoutSet(
    TrackPath aPath,
    double aAlong,
    TrackPath bPath,
    double bAlong,
    math.Point<double> center,
    double radius,
    List<TurntableTurn> out,
  ) {
    final h = aPath.headingAt(aAlong);
    final aDir = math.Point(math.sin(h), -math.cos(h));
    final revDir = math.Point(-aDir.x, -aDir.y);
    final aRevAlong = aPath.length - aAlong;
    final bRevAlong = bPath.length - bAlong;
    // 1. Diverging: SHIFT moves tram from stem lane onto parallel branch.
    out.add(
      TurntableTurn.create(
        from: aPath,
        to: bPath,
        center: center,
        radius: radius,
        fromAlong: aAlong,
        toAlong: bAlong,
        movement: TurntableMovement.turnout,
        autoBoard: false,
        requiredTravelDir: aDir,
      ),
    );
    // 2. Converging forward on reversed branch: merges automatically onto stem.
    out.add(
      TurntableTurn.create(
        from: bPath.reversed,
        to: aPath.reversed,
        center: center,
        radius: radius,
        fromAlong: bRevAlong,
        toAlong: aRevAlong,
        movement: TurntableMovement.turnout,
        autoBoard: true,
        requiredTravelDir: revDir,
      ),
    );
    // 3. Converging in reverse gear on branch: merges automatically onto stem.
    out.add(
      TurntableTurn.create(
        from: bPath,
        to: aPath,
        center: center,
        radius: radius,
        fromAlong: bAlong,
        toAlong: aAlong,
        movement: TurntableMovement.turnout,
        autoBoard: true,
        requiredTravelDir: revDir,
      ),
    );
  }
}
