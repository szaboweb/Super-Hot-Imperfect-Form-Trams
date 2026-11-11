import 'dart:ui';

import 'package:flame/components.dart';

import '../graphics/render_layer.dart';

/// Layer 6 (atmosphere): slowly drifting cloud shadows over the whole map.
/// Placeholder; smoke, rain and fog join here later.
class AtmosphereComponent extends PositionComponent {
  AtmosphereComponent({required this.bounds})
    : super(priority: RenderLayer.atmosphere.priority);

  /// Playable area size in world px, centred on the origin.
  final Vector2 bounds;

  static const double driftPxPerSec = 12;
  static const double margin = 300;

  /// Cloud centres as fractions of the drift span / bounds height, radii in px.
  static const List<({double fx, double fy, double rx, double ry})> _clouds = [
    (fx: 0.15, fy: 0.25, rx: 220, ry: 120),
    (fx: 0.55, fy: 0.7, rx: 280, ry: 140),
    (fx: 0.85, fy: 0.35, rx: 200, ry: 110),
  ];

  double _offset = 0;

  final Paint _shadow = Paint()
    ..color = const Color(0x22000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);

  @override
  void update(double dt) {
    super.update(dt);
    _offset += driftPxPerSec * dt;
  }

  @override
  void render(Canvas canvas) {
    final span = bounds.x + margin * 2;
    for (final c in _clouds) {
      final x = ((c.fx * span + _offset) % span) - span / 2;
      final y = (c.fy - 0.5) * bounds.y;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: c.rx * 2,
          height: c.ry * 2,
        ),
        _shadow,
      );
    }
  }
}
