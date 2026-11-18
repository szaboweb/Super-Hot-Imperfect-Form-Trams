import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../graphics/render_layer.dart';
import '../levels/track_zone_data.dart';
import '../systems/track_zone_system.dart';

/// Layer 3 (track): special surface overlay drawing frosty cyan crystals and
/// speed chevrons for [TrackZoneKind.ice], or bubbling amber tar for [TrackZoneKind.melted].
class TrackZoneComponent extends PositionComponent {
  /// Creates a visual track surface zone from resolved [zone] placement.
  TrackZoneComponent({required this.zone})
    : super(
        position: Vector2(zone.data.x, zone.data.y),
        angle: zone.headingRad,
        size: Vector2(34, zone.data.radius * 2),
        anchor: Anchor.center,
        priority: RenderLayer.track.priority + 1,
      );

  /// Resolved special surface zone metadata and track heading.
  final LoadedTrackZone zone;

  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    switch (zone.data.kind) {
      case TrackZoneKind.ice:
        _renderIce(canvas);
      case TrackZoneKind.melted:
        _renderMelted(canvas);
    }
  }

  void _renderIce(Canvas canvas) {
    final rect = size.toRect();
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas
      ..drawRRect(rrect, Paint()..color = const Color(0x557CE8FF))
      ..drawRRect(
        rrect,
        Paint()
          ..color = const Color(0xAA9FF2FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );

    final crystalPaint = Paint()
      ..color = const Color(0x88E5FBFF)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final chevronPaint = Paint()
      ..color = const Color(0xFFDDFBFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.x / 2;
    final count = math.max(2, (size.y / 22).floor());
    for (var i = 0; i < count; i++) {
      final y = (i + 0.5) * (size.y / count);
      canvas
        ..drawLine(Offset(4, y - 5), Offset(10, y + 3), crystalPaint)
        ..drawLine(
          Offset(size.x - 10, y + 4),
          Offset(size.x - 4, y - 4),
          crystalPaint,
        );
      final chevron = Path()
        ..moveTo(cx - 5, y + 3)
        ..lineTo(cx, y - 3)
        ..lineTo(cx + 5, y + 3);
      canvas.drawPath(chevron, chevronPaint);
    }
  }

  void _renderMelted(Canvas canvas) {
    final rect = size.toRect();
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas
      ..drawRRect(rrect, Paint()..color = const Color(0xB82D180A))
      ..drawRRect(
        rrect,
        Paint()
          ..color = const Color(0xCC99541C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );

    final wavePaint = Paint()
      ..color = const Color(0xFFB3631E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final bubblePaint = Paint()..color = const Color(0xFFE0882B);

    final cx = size.x / 2;
    final count = math.max(2, (size.y / 20).floor());
    for (var i = 0; i < count; i++) {
      final y = (i + 0.5) * (size.y / count);
      final wave = Path()
        ..moveTo(5, y)
        ..quadraticBezierTo(cx - 5, y - 3, cx, y)
        ..quadraticBezierTo(cx + 5, y + 3, size.x - 5, y);
      canvas.drawPath(wave, wavePaint);

      final pulse = 0.5 + 0.5 * math.sin(_time * 3.5 + i * 1.7);
      final bx = cx + (i.isEven ? -7.0 : 7.0);
      canvas.drawCircle(Offset(bx, y - 4), 1.4 + pulse * 1.4, bubblePaint);
    }
  }
}
