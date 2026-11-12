import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_path.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_turn.dart';

void main() {
  // `north` goes up through the origin, `east` goes right through it.
  final north = TrackPath(const [Point(0.0, 300.0), Point(0.0, -300.0)]);
  final east = TrackPath(const [Point(-300.0, 0.0), Point(300.0, 0.0)]);
  const center = Point(0.0, 0.0);
  final right = TurntableTurn.build(from: north, to: east, center: center);
  final left = TurntableTurn.build(from: east, to: north, center: center);

  test('north -> east is a clockwise quarter turn, east -> north counter-clockwise', () {
    expect(right.sweep, closeTo(pi / 2, 0.01));
    expect(left.sweep, closeTo(-pi / 2, 0.01));
  });

  test('offset is measured from the crossing along the loop direction', () {
    expect(right.offsetOf(north, 300), closeTo(0, 0.001));
    expect(right.offsetOf(north, 250), closeTo(-50, 0.001));
    expect(right.offsetOf(east, 250), isNull);
  });

  test(
    'boarding needs the tram on the disc (nose at the edge, tail not off)',
    () {
      const half = 28.0; // reach = 48 + 28 = 76
      expect(
        right.board(north, 300 - 80, 150, half),
        isNull,
        reason: 'too early',
      );
      expect(right.board(north, 300 - 70, 150, half), isNotNull);
      expect(right.board(north, 300 + 30, 150, half), isNotNull);
      expect(
        right.board(north, 300 + 70, 150, half),
        isNotNull,
        reason: 'tail still on the disc',
      );
      expect(
        right.board(north, 300 + 80, 150, half),
        isNull,
        reason: 'tail has left the disc',
      );
      expect(right.board(north, 300, 0, half), isNull, reason: 'stopped');
      expect(right.board(east, 300, 150, half), isNull, reason: 'wrong loop');
    },
  );

  test(
    'ride rotates the disc under the tram and leaves it on the other loop',
    () {
      final ride = right.board(north, 300 - 60, 160, 28)!;
      expect(ride.duration, inInclusiveRange(0.2, 0.6));
      final start = ride.position;
      expect(start.x, closeTo(0, 0.001));
      expect(start.y, closeTo(60, 0.001));

      var guard = 0;
      while (!ride.finished && guard++ < 1000) {
        ride.advance(0.01, 160);
      }
      expect(ride.finished, isTrue);
      expect(ride.angle, closeTo(pi / 2, 0.001));
      expect(ride.heading, closeTo(pi / 2, 0.01));
      final end = ride.position;
      expect(end.y, closeTo(0, 0.5), reason: 'now on the east-west loop');
      expect(end.x, greaterThan(70));
    },
  );

  test('a late press still completes the turn, as fast as needed', () {
    final late = right.board(north, 300 + 10, 300, 28)!;
    expect(late.duration, closeTo(0.22, 0.02));
    while (!late.finished) {
      late.advance(0.01, 300);
    }
    expect(late.angle, closeTo(pi / 2, 0.001));

    // Tail still on the disc, nose long past: any part on the disc counts.
    final lastMoment = right.board(north, 300 + 70, 300, 28)!;
    expect(lastMoment.duration, TurntableTurn.minRideSeconds);
    while (!lastMoment.finished) {
      lastMoment.advance(0.01, 300);
    }
    expect(lastMoment.angle, closeTo(pi / 2, 0.001));
    expect(lastMoment.position.y, closeTo(0, 0.5));
  });
}
