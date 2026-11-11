import 'dart:ui';

import 'package:flame/components.dart';

import '../graphics/render_layer.dart';

/// Layer 5 (canopy): flat rooftop seen from above (AC units, chimney).
/// Must be placed beside the track, never over it, so it can't hide a tram.
/// Placeholder visuals.
class BuildingComponent extends PositionComponent {
  BuildingComponent({
    required Vector2 position,
    required Vector2 size,
    double angle = 0,
  }) : super(
         position: position,
         size: size,
         angle: angle,
         anchor: Anchor.center,
         priority: RenderLayer.canopy.priority,
       );

  @override
  void render(Canvas canvas) {
    final shade = ((position.x * 7 + position.y * 13).abs() % 24).toInt();
    final roof = Color.fromARGB(255, 88 + shade, 92 + shade, 102 + shade);
    final rect = size.toRect();
    canvas
      ..drawRect(rect, Paint()..color = roof)
      ..drawRect(
        rect.deflate(5),
        Paint()
          ..color = const Color(0x33000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      )
      ..drawRect(
        rect,
        Paint()
          ..color = const Color(0xFF2B2E36)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );

    final unit = Paint()..color = const Color(0xFF9AA0AC);
    final chimney = Paint()..color = const Color(0xFF3B3E47);
    canvas
      ..drawRect(Rect.fromLTWH(size.x * 0.15, size.y * 0.2, 16, 12), unit)
      ..drawRect(Rect.fromLTWH(size.x * 0.55, size.y * 0.55, 16, 12), unit)
      ..drawRect(Rect.fromLTWH(size.x * 0.75, size.y * 0.15, 8, 8), chimney);
  }
}
