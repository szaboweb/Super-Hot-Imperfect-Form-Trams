import 'dart:math' as math;

import 'track_path.dart';
import 'turntable_movement.dart';
import 'turntable_turn.dart';
import 'y_turn_path.dart';

/// A tram riding a crossover platform while it moves. By [TurntableTurn.movement]:
/// rotate = the tram drives along the disc's diameter while the disc turns under it;
/// slide = it drives straight while the platform slides it sideways onto the parallel track;
/// reverse = it follows the platform's Y-shaped rails round the arc and leaves backwards.
/// Pure Dart (no Flame).
class TurntableRide {
  TurntableRide({
    required this.turn,
    required this.entry,
    required this.offset,
    required this.duration,
    required this.halfLength,
    this.travelSign = 1.0,
  }) : _entryLength = turn.radius + halfLength,
       _entryHeading = entry.headingAt(turn.alongOn(entry) ?? 0),
       _y = turn.movement == TurntableMovement.reverse
           ? yTurnPath(radius: turn.radius, entry: turn.radius + halfLength)
           : null {
    _leadOffset = math.max(0.0, _signedOffset);
    _startU =
        (turn.movement == TurntableMovement.reverse
            ? math.min(0.0, _signedOffset)
            : _signedOffset) +
        _entryLength;
    _u = _startU;
  }

  final TurntableTurn turn;

  /// The path the tram was on when it boarded (for a reverse: either direction of the loop).
  final TrackPath entry;

  /// Signed px of the tram's centre from the crossing, along [entry]'s direction
  /// (rotate and slide; a reverse follows the Y path instead).
  double offset;

  /// Seconds a rotate or slide takes to complete.
  final double duration;

  /// Half the tram length, to know when its tail has left the platform.
  final double halfLength;

  /// +1.0 when boarding in forward gear, -1.0 when boarding in reverse gear.
  final double travelSign;

  final double _entryLength;
  final double _entryHeading;
  final TrackPath? _y;
  late final double _leadOffset;
  late final double _startU;
  late double _u;
  double _elapsed = 0;

  double get _signedOffset => offset * travelSign;

  TurntableMovement get movement => turn.movement;

  /// 0..1 how far the movement is.
  double get progress {
    final y = _y;
    if (y != null) return (_u / y.length).clamp(0.0, 1.0);
    return (_elapsed / duration).clamp(0.0, 1.0);
  }

  /// Eased rotation of the disc so far (rad, signed; positive = clockwise); 0 unless rotating.
  double get angle =>
      movement == TurntableMovement.rotate ? turn.sweep * _ease(progress) : 0;

  /// Rotation the platform graphics should have: the disc angle when rotating, the
  /// tram's entry heading for a reverse (the Y points the way the tram came), else 0.
  double get platformAngle => switch (movement) {
    TurntableMovement.rotate => angle,
    TurntableMovement.slide => 0,
    TurntableMovement.reverse =>
      _entryHeading + (travelSign < 0 ? math.pi : 0.0),
  };

  /// Eased sideways shift of a sliding platform so far (px); zero for other movements.
  math.Point<double> get slideShift => movement == TurntableMovement.slide
      ? turn.slide * _ease(progress)
      : const math.Point(0, 0);

  /// World position of the tram's centre.
  math.Point<double> get position => switch (movement) {
    TurntableMovement.rotate => _rotated(),
    TurntableMovement.slide => _slid(),
    TurntableMovement.reverse => _reversed(),
  };

  /// World heading of the tram (same convention as `TrackPath.headingAt`).
  double get heading => switch (movement) {
    TurntableMovement.rotate => turn.fromHeading + angle,
    TurntableMovement.slide => turn.fromHeading,
    TurntableMovement.reverse =>
      _entryHeading + _y!.headingAt(_safeYHeadingU()),
  };

  /// Movement done and the whole tram is off the platform: it joins [exitPath].
  bool get finished => movement == TurntableMovement.reverse
      ? _u >= _y!.length
      : progress >= 1 && offset.abs() >= turn.radius + halfLength;

  /// The path the tram continues on: `to` for rotate/slide, the reversed [entry] for a reverse.
  TrackPath get exitPath =>
      movement == TurntableMovement.reverse ? entry.reversed : turn.to;

  /// Px along [exitPath] where the tram's centre is when [finished].
  double get exitDistance => movement == TurntableMovement.reverse
      ? entry.reversed.nearest(turn.center).along + _entryLength * travelSign
      : turn.toAlong + offset;

  void advance(double dt, double speed) {
    _elapsed += dt;
    if (movement == TurntableMovement.reverse) {
      _u += speed.abs() * dt;
    } else {
      offset += speed * dt;
    }
  }

  math.Point<double> _rotated() {
    final p = _turned(
      math.sin(turn.fromHeading) * offset,
      -math.cos(turn.fromHeading) * offset,
      angle,
    );
    return math.Point(turn.center.x + p.x, turn.center.y + p.y);
  }

  math.Point<double> _slid() {
    final shift = slideShift;
    return math.Point(
      turn.fromPoint.x + math.sin(turn.fromHeading) * offset + shift.x,
      turn.fromPoint.y - math.cos(turn.fromHeading) * offset + shift.y,
    );
  }

  math.Point<double> _reversed() {
    final y = _y!;
    final span = y.length - _startU;
    final t = span <= 0 ? 1.0 : ((_u - _startU) / span).clamp(0.0, 1.0);
    final local = y.positionAt(_u.clamp(0.0, y.length));
    final adjustedY = local.y - _leadOffset * (1.0 - t);
    final p = _turned(
      local.x,
      adjustedY,
      _entryHeading + (travelSign < 0 ? math.pi : 0.0),
    );
    return math.Point(turn.center.x + p.x, turn.center.y + p.y);
  }

  /// Keeps heading lookups inside the straight Y stem away from the closed-loop seam.
  double _safeYHeadingU() {
    final limit = math.max(7.0, _y!.length - 7.0);
    return _u.clamp(7.0, limit);
  }

  static math.Point<double> _turned(double x, double y, double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return math.Point(x * c - y * s, x * s + y * c);
  }

  static double _ease(double t) => t * t * (3 - 2 * t);
}
