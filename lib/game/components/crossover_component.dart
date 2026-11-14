import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../input/tram_controls.dart';
import '../graphics/render_layer.dart';
import '../levels/crossover_data.dart';
import '../systems/turntable_movement.dart';
import '../systems/turntable_ride.dart';
import '../systems/turntable_turn.dart';
import 'tram_component.dart';

/// Layer 3 (track): one turntable crossover: signal light and the disc angle that
/// the disc and its L-rail follow. The signal comes from the tram (its own SHIFT, see
/// `TramComponent.requestTurn`); this component only shows it: the disc turns while a
/// tram rides it, swings back to rest afterwards, and the light shows who used it last.
class CrossoverComponent extends PositionComponent {
  CrossoverComponent({
    required this.data,
    required this.turns,
    required this.trams,
  }) : super(
         position: Vector2(data.x + data.signalDx, data.y + data.signalDy),
         size: Vector2.all(18),
         anchor: Anchor.center,
         priority: RenderLayer.track.priority + 3,
       );

  final CrossoverData data;
  final List<TurntableTurn> turns;
  final List<TramComponent> trams;

  /// Time the disc needs to swing back from a quarter turn to rest.
  static const double returnSeconds = 0.5;

  /// Current rotation of the disc (rad, positive = clockwise); 0 = rest.
  double turntableAngle = 0;

  /// How fast a triangle platform swings round to the tram's heading (rad/s).
  static const double swingRate = 12;

  /// Rotation of the platform graphics (rad): the disc angle for rotating platforms,
  /// the rail direction for a sliding one, the last tram heading for a triangle.
  late double platformAngle =
      data.movement == TurntableMovement.slide && turns.isNotEmpty
      ? turns.first.fromHeading - pi / 2
      : 0;

  /// The ride that is moving this platform right now; null at rest.
  TurntableRide? activeRide;

  /// Distance between the two lanes a sliding platform joins (px); 60 if there is no slide.
  double get lanePitch => turns
      .map((t) => t.slideDistance)
      .fold(0.0, (a, b) => max(a, b))
      .clamp(60.0, double.infinity);

  /// Controls of the player whose tram rode this disc last; null if none yet.
  TramControls? lastUser;

  TramComponent? _rider;

  @override
  void update(double dt) {
    super.update(dt);
    final rider = trams
        .where((t) => t.ride != null && turns.contains(t.ride!.turn))
        .firstOrNull;
    if (rider != null && rider != _rider) {
      lastUser = rider.controls;
    }
    _rider = rider;
    activeRide = rider?.ride;
    if (rider != null) {
      turntableAngle = rider.ride!.angle;
    } else {
      final step = (pi / 2) / returnSeconds * dt;
      turntableAngle = turntableAngle.abs() <= step
          ? 0
          : turntableAngle - turntableAngle.sign * step;
    }
    _updatePlatformAngle(dt);
  }

  /// Rotating platforms follow the disc angle; a sliding one keeps its rest angle; a
  /// triangle swings round to point the way the tram that rides it came from.
  void _updatePlatformAngle(double dt) {
    switch (data.movement) {
      case TurntableMovement.rotate:
        platformAngle = turntableAngle;
      case TurntableMovement.slide:
        break;
      case TurntableMovement.reverse:
        final ride = activeRide;
        if (ride == null) return;
        final gap = atan2(
          sin(ride.platformAngle - platformAngle),
          cos(ride.platformAngle - platformAngle),
        );
        final step = swingRate * dt;
        platformAngle += gap.abs() <= step ? gap : step * gap.sign;
    }
  }

  Color get _colour => switch (lastUser) {
    TramControls.wasd => const Color(0xFF3DDC84),
    TramControls.arrows => const Color(0xFFE5483B),
    null => const Color(0xFF9AA0AC),
  };

  @override
  void render(Canvas canvas) {
    final colour = _colour;
    final c = Offset(size.x / 2, size.y / 2);
    final toDisc = Offset(-data.signalDx, -data.signalDy);
    canvas
      ..drawLine(
        c,
        c + toDisc * (1 - data.radius / toDisc.distance),
        Paint()
          ..color = colour.withValues(alpha: 0.35)
          ..strokeWidth = 1.5,
      )
      ..drawCircle(c, size.x / 2, Paint()..color = const Color(0xFF15161B))
      ..drawCircle(c, size.x / 2 - 3, Paint()..color = colour);
  }
}
