import 'dart:math' as math;
import 'dart:ui';

import '../graphics/render_layer.dart';
import '../systems/track_path.dart';
import 'crossover_component.dart';
import 'track_component.dart';

/// Layer 3 (track): the short rail piece on a sliding (rectangle) platform. It is only
/// drawn while a tram rides, lying along the lane it started on and sliding sideways
/// with the platform onto the other lane; at rest the normal track shows through.
class SlideRailComponent extends TrackComponent {
  SlideRailComponent({required this.crossover})
    : super(
        path: TrackPath([
          math.Point<double>(0, crossover.data.radius),
          math.Point<double>(0, -crossover.data.radius),
        ]),
        priority: RenderLayer.track.priority + 2,
      );

  final CrossoverComponent crossover;

  @override
  void update(double dt) {
    super.update(dt);
    final ride = crossover.activeRide;
    if (ride == null) return;
    final from = ride.turn.fromPoint;
    final shift = ride.slideShift;
    position.setValues(from.x + shift.x, from.y + shift.y);
    angle = ride.turn.fromHeading;
  }

  @override
  void render(Canvas canvas) {
    if (crossover.activeRide == null) return;
    super.render(canvas);
  }
}
