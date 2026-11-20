import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../graphics/render_layer.dart';
import '../systems/s_turn_path.dart';
import '../systems/track_path.dart';
import '../systems/turntable_turn.dart';
import 'crossover_component.dart';
import 'track_component.dart';

/// Layer 3 (track): fixed S-curve diverging rails at a [PlatformShape.turnout]
/// switch, showing steel rails and highlighting the active S-curve in cyan.
class SRailComponent extends TrackComponent {
  /// Creates S-curve turnout rails anchored at [crossover].
  SRailComponent({required this.crossover})
    : super(
        path: TrackPath([
          const math.Point<double>(0, 32),
          const math.Point<double>(0, 0),
        ]),
        priority: RenderLayer.track.priority + 2,
      ) {
    position = Vector2(crossover.data.x, crossover.data.y);
  }

  /// Parent crossover holding turnout turns and active ride state.
  final CrossoverComponent crossover;

  final List<_TurnoutBranchPaths> _branches = [];

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
      if (!turn.autoBoard) _branches.add(_buildBranch(turn));
    }
  }

  _TurnoutBranchPaths _buildBranch(
    TurntableTurn turn, {
    double travelSign = 1.0,
  }) {
    final heading = turn.fromHeading + (travelSign < 0 ? math.pi : 0.0);
    final lateralSlide =
        (turn.slide.x * math.cos(turn.fromHeading) +
            turn.slide.y * math.sin(turn.fromHeading)) *
        travelSign;
    final raw = sTurnPath(
      slideDistance: lateralSlide,
      entry: 32.0,
      halfSpan: 32.0,
    );
    final c = math.cos(heading);
    final s = math.sin(heading);
    final ox = turn.fromPoint.x - crossover.data.x;
    final oy = turn.fromPoint.y - crossover.data.y;
    final localPts = [
      for (final p in raw.points)
        math.Point<double>(ox + p.x * c - p.y * s, oy + p.x * s + p.y * c),
    ];
    final localPath = TrackPath(localPts);
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
    final active = _buildBranch(ride.turn, travelSign: ride.travelSign);
    canvas
      ..drawPath(active.left, _activeRailPaint)
      ..drawPath(active.right, _activeRailPaint);
  }
}

typedef _TurnoutBranchPaths = ({Path center, Path left, Path right});
