import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_path.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_movement.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_turn.dart';

void main() {
  // Closed loop (1600 px) that runs north through the origin at distance 300.
  final loop = TrackPath(const [
    Point(0.0, 300.0),
    Point(0.0, -300.0),
    Point(200.0, -300.0),
    Point(200.0, 300.0),
    Point(0.0, 300.0),
  ], name: 'loop');
  final turn = TurntableTurn.build(
    from: loop,
    to: loop,
    center: const Point(0.0, 0.0),
    movement: TurntableMovement.reverse,
  );

  test('reverse turns half way round and exits on the reversed loop', () {
    expect(turn.sweep, closeTo(pi, 0.001));
    expect(turn.to, same(loop.reversed));
  });

  test(
    'boarding only works before the fork (centre not past the platform)',
    () {
      expect(turn.board(loop, 300 - 60, 160, 28), isNotNull);
      expect(turn.board(loop, 300, 160, 28), isNotNull);
      expect(
        turn.board(loop, 300 + 10, 160, 28),
        isNull,
        reason: 'past the fork',
      );
      expect(turn.board(loop, 300 - 90, 160, 28), isNull, reason: 'too early');
    },
  );

  test('the tram follows the Y, ends on the stem and faces the other way', () {
    final ride = turn.board(loop, 300 - 60, 160, 28)!;
    expect(ride.position.x, closeTo(0, 0.001));
    expect(ride.position.y, closeTo(60, 0.001));
    var guard = 0;
    while (ride.progress < 0.95 && guard++ < 2000) {
      ride.advance(0.01, 160);
    }
    expect(cos(ride.heading), lessThan(-0.9), reason: 'now facing south');
    while (!ride.finished && guard++ < 4000) {
      ride.advance(0.01, 160);
    }
    expect(ride.finished, isTrue);
    expect(ride.exitPath, same(loop.reversed));
    final onExit = loop.reversed.positionAt(ride.exitDistance);
    expect(onExit.x, closeTo(0, 0.5));
    expect(onExit.y, closeTo(76, 0.5), reason: 'radius + half length behind');
  });

  test('a tram on the reversed path can reverse back', () {
    final back = loop.reversed;
    final along = back.nearest(const Point(0.0, 0.0)).along;
    final ride = turn.board(back, along - 40, 160, 28);
    expect(ride, isNotNull);
    expect(turn.board(back, along + 10, 160, 28), isNull);
    while (!ride!.finished) {
      ride.advance(0.01, 160);
    }
    expect(ride.exitPath, same(loop));
  });
}
