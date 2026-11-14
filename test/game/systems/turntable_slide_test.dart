import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_path.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_movement.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_turn.dart';

void main() {
  // Two parallel north-bound lanes 60 px apart; the platform sits on the left one.
  final lane = TrackPath(const [Point(0.0, 300.0), Point(0.0, -300.0)]);
  final other = TrackPath(const [Point(60.0, 300.0), Point(60.0, -300.0)]);
  final turn = TurntableTurn.build(
    from: lane,
    to: other,
    center: const Point(0.0, 0.0),
    movement: TurntableMovement.slide,
  );

  test('slide has no sweep and a 60 px sideways distance', () {
    expect(turn.sweep, 0);
    expect(turn.slideDistance, closeTo(60, 0.001));
    expect(turn.slide.x, closeTo(60, 0.001));
    expect(turn.slide.y, closeTo(0, 0.001));
  });

  test(
    'the tram keeps its heading and drifts sideways onto the other lane',
    () {
      final ride = turn.board(lane, 300 - 60, 160, 28)!;
      expect(ride.position.x, closeTo(0, 0.001));
      expect(ride.platformAngle, 0);
      var guard = 0;
      while (!ride.finished && guard++ < 1000) {
        ride.advance(0.01, 160);
        expect(ride.heading, closeTo(0, 0.001));
      }
      expect(ride.finished, isTrue);
      expect(ride.slideShift.x, closeTo(60, 0.001));
      expect(ride.position.x, closeTo(60, 0.001));
    },
  );

  test('the ride leaves on the other lane at the matching distance', () {
    final ride = turn.board(lane, 300 - 60, 160, 28)!;
    while (!ride.finished) {
      ride.advance(0.01, 160);
    }
    expect(ride.exitPath, same(other));
    final onExit = other.positionAt(ride.exitDistance);
    expect(onExit.x, closeTo(ride.position.x, 0.001));
    expect(onExit.y, closeTo(ride.position.y, 0.001));
    expect(ride.exitDistance, greaterThan(300 + 48));
  });
}
