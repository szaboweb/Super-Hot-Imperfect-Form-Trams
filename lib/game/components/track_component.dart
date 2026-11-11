import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../graphics/render_layer.dart';
import '../systems/track_path.dart';

/// Draws a [TrackPath] as ballast, sleepers and two rails (Canvas rendering, no art needed).
class TrackComponent extends PositionComponent {
  TrackComponent({required this.path})
    : super(priority: RenderLayer.track.priority);

  final TrackPath path;

  static const double gauge = 14;
  static const double sleeperSpacing = 14;
  static const double sleeperHalfWidth = 12;
  static const double sampleStep = 6;

  late final Path _sleepers;
  late final Path _railLeft;
  late final Path _railRight;
  late final Path _ballast;

  final Paint _ballastPaint = Paint()
    ..color = const Color(0xFF2E2E39)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 34
    ..strokeJoin = StrokeJoin.round;
  final Paint _sleeperPaint = Paint()
    ..color = const Color(0xFF6B4F3A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4;
  final Paint _railPaint = Paint()
    ..color = const Color(0xFFC9CED6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeJoin = StrokeJoin.round;

  @override
  Future<void> onLoad() async {
    _ballast = Path();
    _railLeft = Path();
    _railRight = Path();
    _sleepers = Path();

    final steps = (path.length / sampleStep).ceil();
    for (var i = 0; i <= steps; i++) {
      final d = math.min(i * sampleStep, path.length);
      final p = path.positionAt(d);
      final a = path.headingAt(d);
      final nx = math.cos(a);
      final ny = math.sin(a);
      final left = Offset(p.x - nx * gauge / 2, p.y - ny * gauge / 2);
      final right = Offset(p.x + nx * gauge / 2, p.y + ny * gauge / 2);
      if (i == 0) {
        _ballast.moveTo(p.x, p.y);
        _railLeft.moveTo(left.dx, left.dy);
        _railRight.moveTo(right.dx, right.dy);
      } else {
        _ballast.lineTo(p.x, p.y);
        _railLeft.lineTo(left.dx, left.dy);
        _railRight.lineTo(right.dx, right.dy);
      }
    }

    for (var d = 0.0; d < path.length; d += sleeperSpacing) {
      final p = path.positionAt(d);
      final a = path.headingAt(d);
      final nx = math.cos(a) * sleeperHalfWidth;
      final ny = math.sin(a) * sleeperHalfWidth;
      _sleepers
        ..moveTo(p.x - nx, p.y - ny)
        ..lineTo(p.x + nx, p.y + ny);
    }
  }

  @override
  void render(Canvas canvas) {
    canvas
      ..drawPath(_ballast, _ballastPaint)
      ..drawPath(_sleepers, _sleeperPaint)
      ..drawPath(_railLeft, _railPaint)
      ..drawPath(_railRight, _railPaint);
  }
}
