import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../graphics/render_layer.dart';
import '../systems/track_graph.dart';
import 'track_component.dart';

/// Layer 3 (track): visual end-of-line hazard marker (deadEnd, river, construction).
class HazardComponent extends PositionComponent {
  /// Creates a hazard marker for [kind] at world [position] facing [headingRad].
  HazardComponent({
    required this.kind,
    required Vector2 position,
    required double headingRad,
  }) : super(
         position: position,
         angle: headingRad,
         size: Vector2(36, 28),
         anchor: Anchor.center,
         priority: RenderLayer.track.priority + 4,
       );

  /// Open-track hazard variant drawn at this track termination.
  final TrackEnd kind;

  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    switch (kind) {
      case TrackEnd.deadEnd:
        _renderDeadEnd(canvas);
      case TrackEnd.construction:
        _renderConstruction(canvas);
      case TrackEnd.river:
        _renderRiver(canvas);
      case TrackEnd.connected:
        break;
    }
  }

  void _renderDeadEnd(Canvas canvas) {
    const cx = 18.0;
    const halfGauge = TrackComponent.gauge / 2;
    final framePaint = Paint()
      ..color = const Color(0xFF23262E)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(
        const Offset(cx - halfGauge, 23),
        const Offset(cx - halfGauge, 9),
        framePaint,
      )
      ..drawLine(
        const Offset(cx + halfGauge, 23),
        const Offset(cx + halfGauge, 9),
        framePaint,
      )
      ..drawRect(
        const Rect.fromLTWH(5, 9, 26, 5),
        Paint()..color = const Color(0xFFF3E9D2),
      );
    final redPaint = Paint()..color = const Color(0xFFE5483B);
    for (final x in const [6.0, 15.0, 24.0]) {
      canvas.drawRect(Rect.fromLTWH(x, 9, 6, 5), redPaint);
    }
    canvas.drawRect(
      const Rect.fromLTWH(5, 9, 26, 5),
      Paint()
        ..color = const Color(0xFF16181E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final padPaint = Paint()..color = const Color(0xFF14151A);
    canvas
      ..drawRect(const Rect.fromLTWH(cx - halfGauge - 2, 14, 4, 3), padPaint)
      ..drawRect(const Rect.fromLTWH(cx + halfGauge - 2, 14, 4, 3), padPaint);
  }

  void _renderConstruction(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, 4, 26, 15),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF3A3530),
    );
    const board = Rect.fromLTWH(4, 10, 28, 6);
    canvas
      ..save()
      ..clipRect(board)
      ..drawRect(board, Paint()..color = const Color(0xFFF3E9D2));
    final stripePaint = Paint()
      ..color = const Color(0xFFE5483B)
      ..strokeWidth = 4;
    for (var x = 2.0; x <= 34.0; x += 8.0) {
      canvas.drawLine(Offset(x, 16), Offset(x + 5, 10), stripePaint);
    }
    canvas
      ..restore()
      ..drawRect(
        board,
        Paint()
          ..color = const Color(0xFF1E2028)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    final leftLit = (_time * 2.5).floor().isEven;
    _drawBeacon(canvas, const Offset(7, 9), lit: leftLit);
    _drawBeacon(canvas, const Offset(29, 9), lit: !leftLit);
  }

  void _drawBeacon(Canvas canvas, Offset center, {required bool lit}) {
    if (lit) {
      canvas.drawCircle(
        center,
        7,
        Paint()
          ..color = const Color(0x88FFB627)
          ..blendMode = BlendMode.plus,
      );
    }
    canvas.drawCircle(
      center,
      2.6,
      Paint()..color = lit ? const Color(0xFFFFB627) : const Color(0xFF5A4318),
    );
  }

  void _renderRiver(Canvas canvas) {
    const cx = 18.0;
    const halfGauge = TrackComponent.gauge / 2;
    final quay = Path()
      ..moveTo(2, 17)
      ..lineTo(10, 14)
      ..lineTo(18, 16)
      ..lineTo(26, 13)
      ..lineTo(34, 16)
      ..lineTo(34, 21)
      ..lineTo(2, 21)
      ..close();
    canvas.drawPath(quay, Paint()..color = const Color(0xFF5B606B));
    final railPaint = Paint()
      ..color = const Color(0xFFC9CED6)
      ..strokeWidth = 2.5;
    canvas
      ..drawLine(
        const Offset(cx - halfGauge, 25),
        const Offset(cx - halfGauge, 11),
        railPaint,
      )
      ..drawLine(
        const Offset(cx + halfGauge, 25),
        const Offset(cx + halfGauge, 10),
        railPaint,
      );
    final waveShift = math.sin(_time * 4) * 2.5;
    final foamPaint = Paint()
      ..color = const Color(0xAA5CE1E6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(6 + waveShift, 7), Offset(17 + waveShift, 6), foamPaint)
      ..drawLine(
        Offset(19 - waveShift, 4),
        Offset(30 - waveShift, 5),
        Paint()
          ..color = const Color(0xCCFFFFFF)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
  }
}
