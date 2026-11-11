import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../graphics/render_layer.dart';
import '../systems/track_path.dart';

/// Layer 5 (canopy): black power cable above the rails plus poles beside them.
/// Placeholder visuals; the pantograph sparks will be spawned in this layer.
class OverheadWireComponent extends PositionComponent {
  OverheadWireComponent({required this.path})
    : super(priority: RenderLayer.canopy.priority + 1);

  final TrackPath path;

  static const double poleSpacing = 150;
  static const double poleOffset = 30;

  late final Path _wire;
  late final Path _arms;
  final List<Offset> _poles = [];

  final Paint _wirePaint = Paint()
    ..color = const Color(0xFF0B0B10)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..strokeJoin = StrokeJoin.round;
  final Paint _poleArmPaint = Paint()
    ..color = const Color(0xFF15161B)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  final Paint _polePaint = Paint()..color = const Color(0xFF15161B);

  @override
  Future<void> onLoad() async {
    _wire = Path();
    final steps = (path.length / 6).ceil();
    for (var i = 0; i <= steps; i++) {
      final p = path.positionAt(math.min(i * 6.0, path.length));
      if (i == 0) {
        _wire.moveTo(p.x, p.y);
      } else {
        _wire.lineTo(p.x, p.y);
      }
    }

    _arms = Path();
    for (var d = 0.0; d < path.length; d += poleSpacing) {
      final p = path.positionAt(d);
      final a = path.headingAt(d);
      final pole = Offset(
        p.x + math.cos(a) * poleOffset,
        p.y + math.sin(a) * poleOffset,
      );
      _poles.add(pole);
      _arms
        ..moveTo(pole.dx, pole.dy)
        ..lineTo(p.x, p.y);
    }
  }

  @override
  void render(Canvas canvas) {
    canvas
      ..drawPath(_arms, _poleArmPaint)
      ..drawPath(_wire, _wirePaint);
    for (final pole in _poles) {
      canvas.drawCircle(pole, 3.5, _polePaint);
    }
  }
}
