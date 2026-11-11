import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_path.dart';

void main() {
  // Closed 100x100 square, clockwise from the top-left corner.
  final square = TrackPath(const [
    Point(0, 0),
    Point(100, 0),
    Point(100, 100),
    Point(0, 100),
    Point(0, 0),
  ]);

  test('length and closed detection', () {
    expect(square.length, closeTo(400, 0.001));
    expect(square.isClosed, isTrue);
  });

  test('closed path wraps around in both directions', () {
    final p = square.positionAt(450);
    expect(p.x, closeTo(50, 0.001));
    expect(p.y, closeTo(0, 0.001));
    final q = square.positionAt(-50);
    expect(q.x, closeTo(0, 0.001));
    expect(q.y, closeTo(50, 0.001));
  });

  test('heading 0 points up, pi/2 points right', () {
    final up = TrackPath(const [Point(0, 0), Point(0, -100)]);
    final right = TrackPath(const [Point(0, 0), Point(100, 0)]);
    expect(up.headingAt(50, lookAround: 1), closeTo(0, 0.001));
    expect(right.headingAt(50, lookAround: 1), closeTo(pi / 2, 0.001));
  });

  test('open path clamps at its ends', () {
    final open = TrackPath(const [Point(0, 0), Point(100, 0)]);
    expect(open.isClosed, isFalse);
    expect(open.positionAt(500).x, closeTo(100, 0.001));
    expect(open.positionAt(-5).x, closeTo(0, 0.001));
  });
}
