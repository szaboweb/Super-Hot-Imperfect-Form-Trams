import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../input/tram_controls.dart';
import '../graphics/render_layer.dart';
import '../levels/crossover_data.dart';
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

  static const double flashSeconds = 0.5;

  /// Time the disc needs to swing back from a quarter turn to rest.
  static const double returnSeconds = 0.5;

  /// Current rotation of the disc (rad, positive = clockwise); 0 = rest.
  double turntableAngle = 0;

  /// Controls of the player whose tram rode this disc last; null if none yet.
  TramControls? lastUser;

  TramComponent? _rider;
  double _flash = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _flash = max(0, _flash - dt);
    final rider = trams
        .where((t) => t.ride != null && turns.contains(t.ride!.turn))
        .firstOrNull;
    if (rider != null && rider != _rider) {
      _flash = flashSeconds;
      lastUser = rider.controls;
    }
    _rider = rider;
    if (rider != null) {
      turntableAngle = rider.ride!.angle;
      return;
    }
    final step = (pi / 2) / returnSeconds * dt;
    turntableAngle = turntableAngle.abs() <= step
        ? 0
        : turntableAngle - turntableAngle.sign * step;
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
    final glow = 0.25 + 0.6 * (_flash / flashSeconds);
    canvas
      ..drawLine(
        c,
        c + toDisc * (1 - data.radius / toDisc.distance),
        Paint()
          ..color = colour.withValues(alpha: 0.35)
          ..strokeWidth = 1.5,
      )
      ..drawCircle(c, size.x / 2, Paint()..color = const Color(0xFF15161B))
      ..drawCircle(
        c,
        size.x / 2 + 5,
        Paint()
          ..color = colour.withValues(alpha: glow)
          ..blendMode = BlendMode.plus,
      )
      ..drawCircle(c, size.x / 2 - 3, Paint()..color = colour);
  }
}
