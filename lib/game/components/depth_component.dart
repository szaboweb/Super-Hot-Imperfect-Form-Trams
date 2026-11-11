import 'dart:ui';

import 'package:flame/components.dart';

import '../graphics/render_layer.dart';

/// Layer 1 (depth): dark riverbed / pit that shows through gaps in the ground.
/// Placeholder: near-black fill with faint ripple lines.
class DepthComponent extends PositionComponent {
  DepthComponent({this.extent = 1500})
    : super(priority: RenderLayer.depth.priority);

  /// Half-size of the filled square in world px (bigger than any camera view).
  final double extent;

  final Paint _fill = Paint()..color = const Color(0xFF05080F);
  final Paint _ripple = Paint()
    ..color = const Color(0x1A4A6A8A)
    ..strokeWidth = 1;

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTRB(-extent, -extent, extent, extent), _fill);
    for (var y = -extent; y < extent; y += 14) {
      canvas.drawLine(Offset(-extent, y), Offset(extent, y), _ripple);
    }
  }
}
