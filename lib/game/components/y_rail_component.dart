import 'package:flame/components.dart';

import '../graphics/render_layer.dart';
import '../systems/y_turn_path.dart';
import 'crossover_component.dart';
import 'track_component.dart';

/// Layer 3 (track): the Y-shaped rails of a triangle platform: a stem and two arms joined
/// by a 180 degree arc. It turns with the platform, so the stem points the way the
/// tram on it came from.
class YRailComponent extends TrackComponent {
  YRailComponent({required this.crossover})
    : super(
        path: yTurnPath(
          radius: crossover.data.radius,
          entry: crossover.data.radius,
        ),
        priority: RenderLayer.track.priority + 2,
      ) {
    position = Vector2(crossover.data.x, crossover.data.y);
  }

  final CrossoverComponent crossover;

  @override
  void update(double dt) {
    super.update(dt);
    angle = crossover.platformAngle;
  }
}
