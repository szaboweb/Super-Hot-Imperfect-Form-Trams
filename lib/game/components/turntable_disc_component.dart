import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../graphics/platform_shape_painter.dart';
import '../graphics/render_layer.dart';
import '../systems/turntable_movement.dart';
import 'crossover_component.dart';

/// Layer 2 (ground, below the rails): the turntable base at a crossover (shape from platformShape, round by default).
/// It turns with the switch ([CrossoverComponent.angle]); the marks and centre cue show its alignment.
class TurntableDiscComponent extends PositionComponent {
  TurntableDiscComponent({required this.crossover})
    : super(
        position: Vector2(crossover.data.x, crossover.data.y),
        priority: RenderLayer.ground.priority + 10,
      );

  final CrossoverComponent crossover;

  final Paint _base = Paint()..color = const Color(0xFF23252C);
  final Paint _rim = Paint()
    ..color = const Color(0xFF8A8F9C)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4;
  final Paint _pit = Paint()
    ..color = const Color(0xFF14151A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10;
  final Paint _mark = Paint()
    ..color = const Color(0xFF4A4E5A)
    ..strokeWidth = 3;

  double get _radius => crossover.data.radius;

  @override
  void update(double dt) {
    super.update(dt);
    angle = crossover.platformAngle;
  }

  @override
  void render(Canvas canvas) {
    final data = crossover.data;
    final shape = platformShapePath(
      data.shape,
      _radius,
      lanePitch: crossover.lanePitch,
    );
    canvas
      ..drawPath(shape, _pit)
      ..drawPath(shape, _base)
      ..drawPath(shape, _rim);
    if (data.movement == TurntableMovement.rotate) {
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        final from = Offset(math.sin(a), -math.cos(a));
        canvas.drawLine(from * (_radius - 9), from * (_radius - 3), _mark);
      }
      canvas.drawCircle(Offset.zero, 5, _mark);
    }
    _renderAlignmentCue(canvas, data.movement);
  }

  void _renderAlignmentCue(Canvas canvas, TurntableMovement movement) {
    final isActive = crossover.activeRide != null;
    final cue = Paint()
      ..color = isActive ? const Color(0xFF5CE1E6) : const Color(0xFFFFB627)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isActive ? 3.0 : 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = switch (movement) {
      TurntableMovement.rotate =>
        Path()
          ..moveTo(0, 14)
          ..quadraticBezierTo(0, 0, 14, 0)
          ..moveTo(9, -4)
          ..lineTo(14, 0)
          ..lineTo(9, 4),
      TurntableMovement.slide =>
        Path()
          ..moveTo(0, -14)
          ..lineTo(0, 14)
          ..moveTo(-4, -9)
          ..lineTo(0, -14)
          ..lineTo(4, -9)
          ..moveTo(-4, 9)
          ..lineTo(0, 14)
          ..lineTo(4, 9),
      TurntableMovement.reverse =>
        Path()
          ..moveTo(0, 14)
          ..lineTo(0, 2)
          ..lineTo(-9, -10)
          ..moveTo(0, 2)
          ..lineTo(9, -10)
          ..moveTo(-4, 9)
          ..lineTo(0, 14)
          ..lineTo(4, 9),
      TurntableMovement.curve =>
        Path()
          ..moveTo(0, 14)
          ..lineTo(0, 2)
          ..quadraticBezierTo(0, -8, -12, -8)
          ..moveTo(0, 2)
          ..quadraticBezierTo(0, -8, 12, -8)
          ..moveTo(-8, -12)
          ..lineTo(-12, -8)
          ..lineTo(-8, -4)
          ..moveTo(8, -12)
          ..lineTo(12, -8)
          ..lineTo(8, -4),
      TurntableMovement.turnout => _turnoutCuePath(),
    };
    canvas.drawPath(path, cue);
  }

  Path _turnoutCuePath() {
    var sign = 1.0;
    if (crossover.turns.isNotEmpty) {
      final t = crossover.turns.first;
      final lat =
          t.slide.x * math.cos(t.fromHeading) +
          t.slide.y * math.sin(t.fromHeading);
      if (lat != 0) sign = lat < 0 ? -1.0 : 1.0;
    }
    final stemY = -sign * 10.0;
    final branchY = sign * 10.0;
    return Path()
      ..moveTo(-14, stemY)
      ..lineTo(14, stemY)
      ..moveTo(10, stemY - 3)
      ..lineTo(14, stemY)
      ..lineTo(10, stemY + 3)
      ..moveTo(-10, stemY)
      ..cubicTo(0, stemY, 0, branchY, 13, branchY)
      ..moveTo(9, branchY - 3)
      ..lineTo(13, branchY)
      ..lineTo(9, branchY + 3);
  }
}
