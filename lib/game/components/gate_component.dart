import 'dart:ui';

import 'package:flame/components.dart';

import '../graphics/render_layer.dart';
import '../systems/gate_system.dart';

/// Layer 3 (track): visual level-crossing barrier gate with signal lamp and
/// animated red/white striped boom swinging between open and closed states.
class GateComponent extends PositionComponent {
  /// Creates a visual barrier for [gate] aligned to its track heading.
  GateComponent({required this.gate})
    : _boomAngle = gate.isClosed ? closedAngle : openAngle,
      super(
        position: Vector2(gate.data.x, gate.data.y),
        angle: gate.headingRad,
        size: Vector2(56, 36),
        anchor: Anchor.center,
        priority: RenderLayer.track.priority + 5,
      );

  /// Barrier angle (rad) when closed horizontally across the tracks.
  static const double closedAngle = 0.0;

  /// Barrier angle (rad) when raised open clear of the tracks.
  static const double openAngle = -1.32;

  static const double _swingSpeed = 8.0;

  /// Runtime gate instance driven by [GateSystem].
  final GateInstance gate;

  double _boomAngle;

  @override
  void update(double dt) {
    super.update(dt);
    final target = gate.isClosed ? closedAngle : openAngle;
    final diff = target - _boomAngle;
    final step = _swingSpeed * dt;
    _boomAngle = diff.abs() <= step ? target : _boomAngle + step * diff.sign;
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final pivot = Offset(cx + 18, cy);

    _renderBoom(canvas, pivot);
    _renderPostAndLamp(canvas, pivot);
  }

  void _renderBoom(Canvas canvas, Offset pivot) {
    const boomLen = 36.0;
    const stripeCount = 6;
    final segLen = boomLen / stripeCount;
    canvas
      ..save()
      ..translate(pivot.dx, pivot.dy)
      ..rotate(_boomAngle);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-boomLen, -2.5, boomLen, 5),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF15171E),
    );
    for (var i = 0; i < stripeCount; i++) {
      final isRed = i.isEven;
      canvas.drawRect(
        Rect.fromLTWH(-boomLen + i * segLen + 0.5, -1.8, segLen - 0.5, 3.6),
        Paint()
          ..color = isRed ? const Color(0xFFE5483B) : const Color(0xFFF3E9D2),
      );
    }
    canvas.restore();
  }

  void _renderPostAndLamp(Canvas canvas, Offset pivot) {
    final lampColor = gate.isClosed
        ? const Color(0xFFE5483B)
        : const Color(0xFF3DDC84);
    canvas
      ..drawCircle(pivot, 6, Paint()..color = const Color(0xFF181A22))
      ..drawCircle(pivot, 4, Paint()..color = const Color(0xFF4A4E5A));

    final lampPos = Offset(pivot.dx + 4, pivot.dy - 7);
    canvas
      ..drawCircle(
        lampPos,
        6.5,
        Paint()..color = lampColor.withValues(alpha: 0.28),
      )
      ..drawCircle(lampPos, 4.2, Paint()..color = const Color(0xFF14161D))
      ..drawCircle(lampPos, 2.8, Paint()..color = lampColor);
  }
}
