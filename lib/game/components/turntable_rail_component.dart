import 'dart:math' as math;

import 'package:flame/components.dart';

import '../graphics/render_layer.dart';
import '../systems/track_path.dart';
import 'crossover_component.dart';
import 'track_component.dart';

/// Layer 3 (track): the L-shaped rail piece on the turntable. At rest its legs point
/// north and east; it turns with the disc, so after a turn it joins the tram's
/// entry loop to its exit loop.
class TurntableRailComponent extends TrackComponent {
  TurntableRailComponent({required this.crossover})
    : super(
        path: _lPath(crossover.data.radius),
        priority: RenderLayer.track.priority + 2,
      ) {
    position = Vector2(crossover.data.x, crossover.data.y);
  }

  final CrossoverComponent crossover;

  /// North leg, a rounded corner and the east leg, in the disc's own coordinates.
  static TrackPath _lPath(double radius) {
    const corner = 18.0;
    const steps = 8;
    return TrackPath([
      math.Point<double>(0, -radius),
      const math.Point<double>(0, -corner),
      for (var i = 1; i < steps; i++) _bend(corner, i / steps),
      const math.Point<double>(corner, 0),
      math.Point<double>(radius, 0),
    ]);
  }

  /// Quadratic bend from (0, -corner) to (corner, 0) with its control point at the origin.
  static math.Point<double> _bend(double corner, double t) =>
      math.Point<double>(t * t * corner, -(1 - t) * (1 - t) * corner);

  @override
  void update(double dt) {
    super.update(dt);
    angle = crossover.turntableAngle;
  }
}
