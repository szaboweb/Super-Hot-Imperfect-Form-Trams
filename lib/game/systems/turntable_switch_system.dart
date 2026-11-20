import 'dart:math' as math;

import 'track_path.dart';
import 'turntable_movement.dart';
import 'turntable_ride.dart';
import 'turntable_turn.dart';

/// What one SHIFT signal from a tram does: a [ride] on the disc it is on, or a miss.
class TurnDecision {
  const TurnDecision({
    required this.turn,
    required this.offset,
    required this.halfLength,
    this.ride,
    this.isOccupied = false,
  });

  /// The disc that was boarded (hit), else the nearest disc on the tram's loop; null if none.
  final TurntableTurn? turn;

  /// Signed px of the tram's centre from [turn]'s disc centre; null if [turn] is null.
  final double? offset;
  final double halfLength;

  /// The ride to start; null = MISS.
  final TurntableRide? ride;

  /// True when a matching platform could not be boarded because another tram is riding it.
  final bool isOccupied;

  bool get isHit => ride != null;

  /// One log line for this decision, e.g. `W/S L-SHIFT: -23.0px from the disc centre (...) -> HIT, ...`.
  String describe({required String tramLabel, required String keyLabel}) {
    final turn = this.turn;
    final offset = this.offset;
    final where = (turn == null || offset == null)
        ? 'not on a turntable loop'
        : '${offset.toStringAsFixed(1)}px from the disc centre '
              '(on the disc within ±${(turn.radius + halfLength).round()}px)';
    final outcome = (turn != null && isHit)
        ? 'HIT, ${_movementText(turn)}'
        : (isOccupied ? 'BUSY (platform occupied)' : 'MISS');
    return '$tramLabel $keyLabel: $where -> $outcome';
  }

  static String _movementText(TurntableTurn turn) => switch (turn.movement) {
    TurntableMovement.rotate =>
      'disc turns ${(turn.sweep * 180 / math.pi).round()}°',
    TurntableMovement.slide =>
      'platform slides ${turn.slideDistance.round()}px',
    TurntableMovement.reverse => 'Y-turn reverses the tram',
    TurntableMovement.curve =>
      'T-switch curves ${(turn.sweep * 180 / math.pi).round()}°',
    TurntableMovement.turnout =>
      'Y-turnout shifts ${turn.slideDistance.round()}px',
  };
}

/// Decides what a tram's SHIFT signal does, given all turntables of the level.
/// Pure Dart (no Flame), so the rules are unit-testable without components.
class TurntableSwitchSystem {
  const TurntableSwitchSystem(this.turns);

  /// Minimum time between two SHIFT signals of one tram (1/3 s); faster presses are ignored.
  static const double signalCooldownSeconds = 1 / 3;

  final List<TurntableTurn> turns;

  /// The first disc the tram (centre at [distance] on [path], moving [speed] px/s)
  /// is on and that can still turn in time becomes a ride; if [turnSteer] is non-zero
  /// or [desiredDirection] is given, filters/prefers turns matching the steering input.
  /// Platforms whose centre is in [occupiedCenters] are locked and yield a BUSY decision.
  TurnDecision decide({
    required TrackPath path,
    required double distance,
    required double speed,
    required double halfLength,
    math.Point<double>? desiredDirection,
    double turnSteer = 0,
    Iterable<math.Point<double>> occupiedCenters = const [],
  }) {
    final candidates = <({TurntableTurn turn, TurntableRide ride})>[];
    TurntableTurn? busyTurn;
    for (final turn in turns) {
      if (turn.autoBoard) continue;
      final ride = turn.board(path, distance, speed, halfLength);
      if (ride == null) continue;
      if (!_matchesCurveSteer(turn, desiredDirection, turnSteer)) continue;
      if (_isOccupied(turn.center, occupiedCenters)) {
        busyTurn ??= turn;
      } else {
        candidates.add((turn: turn, ride: ride));
      }
    }
    if (candidates.isNotEmpty) {
      final chosen = _pickCandidate(candidates, desiredDirection, turnSteer);
      return TurnDecision(
        turn: chosen.turn,
        offset: chosen.turn.offsetOf(path, distance),
        halfLength: halfLength,
        ride: chosen.ride,
      );
    }
    final fallback = busyTurn ?? _nearest(path, distance);
    return TurnDecision(
      turn: fallback,
      offset: fallback?.offsetOf(path, distance),
      halfLength: halfLength,
      isOccupied: busyTurn != null,
    );
  }

  /// Checks whether the tram automatically boards a converging (`autoBoard`)
  /// turnout switch near the platform centre without pressing SHIFT.
  TurnDecision? checkAutoBoard({
    required TrackPath path,
    required double distance,
    required double speed,
    required double halfLength,
    Iterable<math.Point<double>> occupiedCenters = const [],
  }) {
    if (speed == 0) return null;
    final travelSign = speed < 0 ? -1.0 : 1.0;
    for (final turn in turns) {
      if (!turn.autoBoard) continue;
      final offset = turn.offsetOf(path, distance);
      if (offset == null) continue;
      final signedOffset = offset * travelSign;
      if (signedOffset < -10.0 || signedOffset > 10.0) continue;
      if (_isOccupied(turn.center, occupiedCenters)) continue;
      final ride = turn.board(path, distance, speed, halfLength);
      if (ride != null) {
        return TurnDecision(
          turn: turn,
          offset: offset,
          halfLength: halfLength,
          ride: ride,
        );
      }
    }
    return null;
  }

  static bool _matchesCurveSteer(
    TurntableTurn turn,
    math.Point<double>? desiredDirection,
    double turnSteer,
  ) {
    if (turn.movement != TurntableMovement.curve) return true;
    if (turnSteer != 0) return turn.sweep * turnSteer > 0.1;
    return desiredDirection != null && _exitDot(turn, desiredDirection) > 0.5;
  }

  static bool _isOccupied(
    math.Point<double> center,
    Iterable<math.Point<double>> occupiedCenters,
  ) {
    for (final c in occupiedCenters) {
      if (c.distanceTo(center) < 1.0) return true;
    }
    return false;
  }

  static ({TurntableTurn turn, TurntableRide ride}) _pickCandidate(
    List<({TurntableTurn turn, TurntableRide ride})> candidates,
    math.Point<double>? desired,
    double turnSteer,
  ) {
    if (turnSteer != 0) {
      final steered = [
        for (final c in candidates)
          if (c.turn.sweep * turnSteer > 0.1) c,
      ];
      if (steered.isNotEmpty) {
        for (final c in steered) {
          if (c.turn.movement == TurntableMovement.curve) return c;
        }
        return _pickByDirection(steered, desired);
      }
    }
    return _pickByDirection(candidates, desired);
  }

  static double _exitDot(TurntableTurn turn, math.Point<double> desired) {
    final h = turn.to.headingAt(turn.toAlong);
    return math.sin(h) * desired.x - math.cos(h) * desired.y;
  }

  static ({TurntableTurn turn, TurntableRide ride}) _pickByDirection(
    List<({TurntableTurn turn, TurntableRide ride})> candidates,
    math.Point<double>? desired,
  ) {
    if (desired == null) return candidates.first;
    ({TurntableTurn turn, TurntableRide ride})? best;
    var bestDot = 0.5;
    for (final c in candidates) {
      final dot = _exitDot(c.turn, desired);
      if (dot > bestDot) {
        bestDot = dot;
        best = c;
      }
    }
    return best ?? candidates.first;
  }

  TurntableTurn? _nearest(TrackPath path, double distance) {
    TurntableTurn? best;
    double? bestGap;
    for (final turn in turns) {
      final offset = turn.offsetOf(path, distance);
      if (offset == null) continue;
      if (bestGap == null || offset.abs() < bestGap) {
        best = turn;
        bestGap = offset.abs();
      }
    }
    return best;
  }
}
