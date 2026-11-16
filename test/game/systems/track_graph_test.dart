import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_graph.dart';

void main() {
  TrackGraph build() => TrackGraph(
    segments: const [
      TrackSegment(id: 'main', nextSegment: 'loop'),
      TrackSegment(id: 'river_spur', end: TrackEnd.river),
      TrackSegment(id: 'loop', end: TrackEnd.construction),
    ],
  );

  test('connected segments resolve to nextSegment', () {
    final g = build();
    final step = g.advance('main');
    expect(step.end, TrackEnd.connected);
    expect(step.next, 'loop');
  });

  test('hazard segments report how the tram ends', () {
    final g = build();
    expect(g.advance('river_spur').end, TrackEnd.river);
    expect(g.advance('loop').end, TrackEnd.construction);
  });
}
