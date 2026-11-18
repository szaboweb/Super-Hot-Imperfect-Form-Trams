import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../graphics/render_layer.dart';
import '../systems/track_graph.dart';
import '../systems/tram_pose_trail.dart';
import 'tram_component.dart';

/// Layer 4 (entities): articulated rear trailer car and accordion bellows following a [TramComponent].
class TramTrailerComponent extends PositionComponent {
  /// Creates a rear trailer coupled [lagPx] behind [lead].
  TramTrailerComponent({required this.lead})
    : super(
        size: Vector2(18, 38),
        anchor: Anchor.center,
        priority: RenderLayer.entities.priority - 1,
      ) {
    _trail.reset(math.Point(lead.position.x, lead.position.y), lead.angle);
    _syncToTrail();
  }

  /// Arc-length lag (px) between the lead car's centre and this trailer's centre.
  static const double lagPx = 44.0;

  static const Radius _hullRadius = Radius.circular(3.5);
  static const double _bodyTopY = 7.0;
  static const double _bellowsHalfWidth = 6.0;

  /// Motor car pulling this articulated trailer.
  final TramComponent lead;

  final TramPoseTrail _trail = TramPoseTrail();

  @override
  void update(double dt) {
    super.update(dt);
    if (!lead.isCrashed) {
      _trail.record(math.Point(lead.position.x, lead.position.y), lead.angle);
      _syncToTrail();
      return;
    }
    if (lead.crashHazard == TrackEnd.river) {
      priority = RenderLayer.depth.priority + 4;
      scale.setFrom(lead.scale);
      angle += 0.4 * dt;
    }
  }

  void _syncToTrail() {
    final sample = _trail.sampleBehind(lagPx);
    position.setValues(sample.position.x, sample.position.y);
    angle = sample.heading;
  }

  @override
  void render(Canvas canvas) {
    final bodyRect = Rect.fromLTWH(0, _bodyTopY, size.x, size.y - _bodyTopY);
    final bodyRRect = RRect.fromRectAndRadius(bodyRect, _hullRadius);
    if (lead.crashHazard != TrackEnd.river) {
      canvas.drawRRect(
        bodyRRect.shift(const Offset(3, 4)),
        Paint()..color = const Color(0x50000000),
      );
    }
    _renderBellows(canvas);
    _renderBody(canvas, bodyRect, bodyRRect);
  }

  void _renderBellows(Canvas canvas) {
    final leadRearX =
        lead.position.x - math.sin(lead.angle) * (TramComponent.halfLength - 1);
    final leadRearY =
        lead.position.y + math.cos(lead.angle) * (TramComponent.halfLength - 1);
    final invScale = scale.x > 0.05 ? 1.0 / scale.x : 1.0;
    final dx = (leadRearX - position.x) * invScale;
    final dy = (leadRearY - position.y) * invScale;
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    final target = Offset(
      size.x / 2 + dx * cosA + dy * sinA,
      size.y / 2 - dx * sinA + dy * cosA,
    );
    final front = Offset(size.x / 2, _bodyTopY + 1);
    final gap = (target - front).distance;
    if (gap < 0.5 || gap > 36) return;

    final bellows = Path()
      ..moveTo(front.dx - _bellowsHalfWidth, front.dy)
      ..lineTo(front.dx + _bellowsHalfWidth, front.dy)
      ..lineTo(target.dx + _bellowsHalfWidth, target.dy)
      ..lineTo(target.dx - _bellowsHalfWidth, target.dy)
      ..close();
    canvas
      ..drawPath(bellows, Paint()..color = const Color(0xFF1D2028))
      ..drawPath(
        bellows,
        Paint()
          ..color = const Color(0xFF101218)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    final ribPaint = Paint()
      ..color = const Color(0xFF4A4F5D)
      ..strokeWidth = 1.4;
    for (final t in const [0.25, 0.5, 0.75]) {
      final mid = Offset.lerp(front, target, t)!;
      canvas.drawLine(
        Offset(mid.dx - _bellowsHalfWidth + 0.8, mid.dy),
        Offset(mid.dx + _bellowsHalfWidth - 0.8, mid.dy),
        ribPaint,
      );
    }
  }

  void _renderBody(Canvas canvas, Rect bodyRect, RRect bodyRRect) {
    final isSurfaceWreck = lead.isCrashed && lead.crashHazard != TrackEnd.river;
    canvas.drawRRect(
      bodyRRect,
      Paint()..color = isSurfaceWreck ? const Color(0xFF3A3E48) : lead.color,
    );
    canvas.drawRect(
      Rect.fromLTWH(4, _bodyTopY + 5, size.x - 8, bodyRect.height - 11),
      Paint()..color = const Color(0x3614171F),
    );
    if (!lead.isCrashed) {
      canvas.drawRect(
        Rect.fromLTWH(3, size.y - 3, size.x - 6, 2),
        Paint()..color = const Color(0xFFD6453A),
      );
      return;
    }
    if (lead.crashHazard == TrackEnd.river) {
      final submerge = ((1.0 - scale.x) / 0.38).clamp(0.0, 1.0);
      canvas.drawRRect(
        bodyRRect,
        Paint()
          ..color = const Color(0xFF061426).withValues(alpha: 0.72 * submerge),
      );
    }
  }
}
