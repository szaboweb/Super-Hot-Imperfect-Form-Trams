import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../graphics/render_layer.dart';

/// Layer 3 (track): ground-mounted signal light with a direction arrow.
/// [green] = go, otherwise red. Placeholder visuals.
class SignalComponent extends PositionComponent {
  SignalComponent({
    required Vector2 position,
    required double rotationDeg,
    required this.green,
  }) : super(
         position: position,
         angle: rotationDeg * math.pi / 180,
         size: Vector2.all(18),
         anchor: Anchor.center,
         priority: RenderLayer.track.priority + 1,
       );

  bool green;

  @override
  void render(Canvas canvas) {
    final colour = green ? const Color(0xFF3DDC84) : const Color(0xFFE5483B);
    final c = Offset(size.x / 2, size.y / 2);
    canvas
      ..drawCircle(c, size.x / 2, Paint()..color = const Color(0xFF15161B))
      ..drawCircle(
        c,
        size.x / 2 + 5,
        Paint()
          ..color = colour.withValues(alpha: 0.25)
          ..blendMode = BlendMode.plus,
      )
      ..drawPath(
        Path()
          ..moveTo(c.dx, c.dy - 6)
          ..lineTo(c.dx + 5, c.dy + 4)
          ..lineTo(c.dx - 5, c.dy + 4)
          ..close(),
        Paint()..color = colour,
      );
  }
}
