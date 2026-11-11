import 'dart:ui';

import 'package:flame/components.dart';

import '../graphics/render_layer.dart';
import 'tram_component.dart';

/// Layer 6 (atmosphere): additive headlight cone in front of a [TramComponent]
/// (`BlendMode.screen`). Lives above the tram, so it follows it each frame.
class HeadlightComponent extends PositionComponent {
  HeadlightComponent({required this.tram})
    : super(priority: RenderLayer.atmosphere.priority + 1);

  final TramComponent tram;

  static const double reach = 170;
  static const double nose = 28;

  late final Path _cone;
  late final Paint _paint;

  @override
  Future<void> onLoad() async {
    _cone = Path()
      ..moveTo(-6, -nose)
      ..lineTo(-46, -reach)
      ..lineTo(46, -reach)
      ..lineTo(6, -nose)
      ..close();
    _paint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = Gradient.linear(
        const Offset(0, -nose),
        const Offset(0, -reach),
        const [Color(0x66FFF2B0), Color(0x00FFF2B0)],
      );
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.setFrom(tram.position);
    angle = tram.angle;
  }

  @override
  void render(Canvas canvas) => canvas.drawPath(_cone, _paint);
}
