import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/crossover_data.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_graph.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_movement.dart';

void main() {
  final segments = {
    'a': const TrackSegment(
      id: 'a',
      points: [Point(0.0, 300.0), Point(0.0, -300.0)],
    ),
    'b': const TrackSegment(
      id: 'b',
      points: [Point(-300.0, 0.0), Point(300.0, 0.0)],
    ),
    'lane': const TrackSegment(
      id: 'lane',
      points: [Point(60.0, 300.0), Point(60.0, -300.0)],
    ),
  };

  List<String> check(
    PlatformShape shape,
    String from,
    String to, {
    double x = 0,
  }) => CrossoverData(
    id: 'x',
    x: x,
    y: 0,
    shape: shape,
    links: [(from: from, to: to)],
  ).validate(segments);

  test('shape decides the movement', () {
    const links = <CrossoverLinkData>[];
    CrossoverData of(PlatformShape s) =>
        CrossoverData(id: 'x', x: 0, y: 0, links: links, shape: s);
    expect(of(PlatformShape.circle).movement, TurntableMovement.rotate);
    expect(of(PlatformShape.square).movement, TurntableMovement.rotate);
    expect(of(PlatformShape.rectangle).movement, TurntableMovement.slide);
    expect(of(PlatformShape.triangle).movement, TurntableMovement.reverse);
  });

  test('a slide accepts a parallel lane up to the radius away', () {
    expect(check(PlatformShape.rectangle, 'a', 'lane', x: 30), isEmpty);
    expect(check(PlatformShape.rectangle, 'a', 'lane'), isNotEmpty);
  });

  test('a slide between non-parallel segments is rejected', () {
    expect(check(PlatformShape.rectangle, 'a', 'b'), isNotEmpty);
  });

  test('a triangle needs from == to', () {
    expect(check(PlatformShape.triangle, 'a', 'a'), isEmpty);
    expect(check(PlatformShape.triangle, 'a', 'b'), isNotEmpty);
  });

  test('a circle needs two different segments crossing at the centre', () {
    expect(check(PlatformShape.circle, 'a', 'b'), isEmpty);
    expect(check(PlatformShape.circle, 'a', 'a'), isNotEmpty);
    expect(check(PlatformShape.circle, 'a', 'lane'), isNotEmpty);
  });
}
