import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/components/tram_component.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_path.dart';

void main() {
  final path = TrackPath(const [Point(0, 0), Point(0, -500)]);

  test('accelerating tram advances along the path and faces its direction', () {
    final tram = TramComponent(path: path)..throttle = 1;
    tram.update(0.5);
    expect(tram.trackDistance, greaterThan(0));
    expect(tram.position.y, lessThan(0));
    expect(tram.position.x, closeTo(0, 0.001));
    expect(tram.angle, closeTo(0, 0.001));
    expect(tram.speed, lessThanOrEqualTo(TramComponent.maxSpeed));
  });

  test('tram starts exactly on the path at the given distance', () {
    final tram = TramComponent(path: path, trackDistance: 100);
    expect(tram.position.y, closeTo(-100, 0.001));
  });
}
