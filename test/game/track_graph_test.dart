import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_graph.dart';

void main() {
  TrackGraph build() => TrackGraph(
    segments: const [
      TrackSegment(id: 'main', nextSwitch: 'sw1'),
      TrackSegment(id: 'river_spur', end: TrackEnd.river),
      TrackSegment(id: 'loop', end: TrackEnd.construction),
    ],
    switches: [
      SwitchNode(id: 'sw1', straight: 'loop', diverging: 'river_spur'),
    ],
  );

  test('flipping a switch after a tram passed reroutes the next tram', () {
    final g = build();
    expect(g.advance('main').next, 'loop');
    g.switches['sw1']!.toggle();
    expect(g.advance('main').next, 'river_spur');
  });

  test('hazard segments report how the tram ends', () {
    final g = build();
    expect(g.advance('river_spur').end, TrackEnd.river);
    expect(g.advance('loop').end, TrackEnd.construction);
  });
}
