import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../graphics/render_layer.dart';
import 'crossover_component.dart';

/// Layer 2 (ground, below the rails): the round turntable base at a crossover.
/// It turns with the switch ([CrossoverComponent.angle]); the marks show the rotation.
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
    ..strokeWidth = 3;
  final Paint _mark = Paint()
    ..color = const Color(0xFF4A4E5A)
    ..strokeWidth = 3;

  double get _radius => crossover.data.radius;

  @override
  void update(double dt) {
    super.update(dt);
    angle = crossover.turntableAngle;
  }

  @override
  void render(Canvas canvas) {
    canvas
      ..drawCircle(Offset.zero, _radius + 6, _pit)
      ..drawCircle(Offset.zero, _radius, _base)
      ..drawCircle(Offset.zero, _radius, _rim);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final from = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(from * (_radius - 9), from * (_radius - 3), _mark);
    }
    canvas.drawCircle(Offset.zero, 5, _mark);
  }
}
