import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../graphics/render_layer.dart';
import '../systems/curve_turn_path.dart';
import '../systems/track_path.dart';
import 'crossover_component.dart';
import 'track_component.dart';

/// Layer 3 (track): fixed wye turnout rails at a [PlatformShape.wye] switch,
/// showing grey/silver curved branches and highlighting the active arc in cyan.
class WyeRailComponent extends TrackComponent {
  /// Creates wye turnout rails anchored at [crossover].
  WyeRailComponent({required this.crossover})
    : super(
        path: TrackPath([
          math.Point<double>(0, crossover.data.radius),
          const math.Point<double>(0, 0),
        ]),
        priority: RenderLayer.track.priority + 2,
      ) {
    position = Vector2(crossover.data.x, crossover.data.y);
  }

  /// Parent crossover holding turns and active ride state.
  final CrossoverComponent crossover;

  final List<_WyeBranchPaths> _branches = [];

  final Paint _ballastPaint = Paint()
    ..color = const Color(0xFF2E2E39)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 28
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  final Paint _railPaint = Paint()
    ..color = const Color(0xFFC9CED6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeJoin = StrokeJoin.round;

  final Paint _activeRailPaint = Paint()
    ..color = const Color(0xFF5CE1E6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.2
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  Future<void> onLoad() async {
    for (final turn in crossover.turns) {
      _branches.add(_buildBranch(turn.fromHeading, turn.sweep));
    }
  }

  _WyeBranchPaths _buildBranch(double fromHeading, double sweep) {
    final radius = crossover.data.radius;
    final raw = curveTurnPath(radius: radius, entry: radius, sweep: sweep);
    final c = math.cos(fromHeading);
    final s = math.sin(fromHeading);
    final worldPts = [
      for (final p in raw.points)
        math.Point<double>(p.x * c - p.y * s, p.x * s + p.y * c),
    ];
    final localPath = TrackPath(worldPts);
    final center = Path();
    final left = Path();
    final right = Path();
    const halfGauge = TrackComponent.gauge / 2;
    const step = TrackComponent.sampleStep;
    final count = math.max(1, (localPath.length / step).ceil());
    for (var i = 0; i <= count; i++) {
      final d = math.min(i * step, localPath.length);
      final pt = localPath.positionAt(d);
      final h = localPath.headingAt(d, lookAround: 2);
      final nx = math.cos(h) * halfGauge;
      final ny = math.sin(h) * halfGauge;
      if (i == 0) {
        center.moveTo(pt.x, pt.y);
        left.moveTo(pt.x - nx, pt.y - ny);
        right.moveTo(pt.x + nx, pt.y + ny);
      } else {
        center.lineTo(pt.x, pt.y);
        left.lineTo(pt.x - nx, pt.y - ny);
        right.lineTo(pt.x + nx, pt.y + ny);
      }
    }
    return (center: center, left: left, right: right);
  }

  @override
  void render(Canvas canvas) {
    for (final b in _branches) {
      canvas
        ..drawPath(b.center, _ballastPaint)
        ..drawPath(b.left, _railPaint)
        ..drawPath(b.right, _railPaint);
    }
    final ride = crossover.activeRide;
    if (ride == null) return;
    final heading =
        ride.turn.fromHeading + (ride.travelSign < 0 ? math.pi : 0.0);
    final active = _buildBranch(heading, ride.turn.sweep);
    canvas
      ..drawPath(active.left, _activeRailPaint)
      ..drawPath(active.right, _activeRailPaint);
  }
}

typedef _WyeBranchPaths = ({Path center, Path left, Path right});
