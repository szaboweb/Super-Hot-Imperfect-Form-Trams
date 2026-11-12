import 'dart:math' as math;

import 'turntable_turn.dart';

/// A tram riding a turntable while it rotates. The tram keeps moving along the
/// disc's diameter at its own speed; the disc turns by [TurntableTurn.sweep] under it,
/// so the tram leaves along the other loop. Pure Dart (no Flame).
class TurntableRide {
  TurntableRide({
    required this.turn,
    required this.offset,
    required this.duration,
    required this.halfLength,
  });

  final TurntableTurn turn;

  /// Signed px of the tram's centre from the disc centre, along the disc's own diameter.
  double offset;

  /// Seconds the disc takes to complete its rotation.
  final double duration;

  /// Half the tram length, to know when its tail has left the disc.
  final double halfLength;

  double _elapsed = 0;

  double get progress => (_elapsed / duration).clamp(0.0, 1.0);

  /// Eased rotation of the disc so far (rad, signed; positive = clockwise).
  double get angle => turn.sweep * _ease(progress);

  /// World position of the tram's centre.
  math.Point<double> get position {
    final x = math.sin(turn.fromHeading) * offset;
    final y = -math.cos(turn.fromHeading) * offset;
    final c = math.cos(angle);
    final s = math.sin(angle);
    return math.Point(
      turn.center.x + x * c - y * s,
      turn.center.y + x * s + y * c,
    );
  }

  /// World heading of the tram (same convention as `TrackPath.headingAt`).
  double get heading => turn.fromHeading + angle;

  /// Rotation done and the whole tram is off the disc: it joins [TurntableTurn.to].
  bool get finished =>
      progress >= 1 && offset.abs() >= turn.radius + halfLength;

  void advance(double dt, double speed) {
    _elapsed += dt;
    offset += speed * dt;
  }

  static double _ease(double t) => t * t * (3 - 2 * t);
}
