import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_path.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_switch_system.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_turn.dart';

void main() {
  final north = TrackPath(const [Point(0.0, 300.0), Point(0.0, -300.0)]);
  final east = TrackPath(const [Point(-300.0, 0.0), Point(300.0, 0.0)]);
  final turn = TurntableTurn.build(
    from: north,
    to: east,
    center: const Point(0.0, 0.0),
  );
  final system = TurntableSwitchSystem([turn]);

  TurnDecision decide(double distance, {double speed = 150, TrackPath? on}) =>
      system.decide(
        path: on ?? north,
        distance: distance,
        speed: speed,
        halfLength: 28,
      );

  test('a tram on the disc gets a ride and a HIT line', () {
    final decision = decide(270);
    expect(decision.isHit, isTrue);
    expect(decision.ride, isNotNull);
    expect(decision.offset, closeTo(-30, 0.001));
    expect(
      decision.describe(tramLabel: 'W/S', keyLabel: 'L-SHIFT'),
      'W/S L-SHIFT: -30.0px from the disc centre (on the disc within ±76px) '
      '-> HIT, disc turns 90°',
    );
  });

  test('off the disc is a MISS that still names the distance', () {
    final decision = decide(100);
    expect(decision.isHit, isFalse);
    expect(decision.offset, closeTo(-200, 0.001));
    expect(
      decision.describe(tramLabel: 'ARROWS', keyLabel: 'R-SHIFT'),
      contains('-200.0px from the disc centre'),
    );
    expect(
      decision.describe(tramLabel: 'ARROWS', keyLabel: 'R-SHIFT'),
      endsWith('MISS'),
    );
  });

  test('any part of the tram on the disc is a HIT, even at top speed', () {
    final decision = decide(360, speed: 300);
    expect(decision.isHit, isTrue);
    expect(decision.offset, closeTo(60, 0.001));
    expect(decision.ride!.duration, TurntableTurn.minRideSeconds);
  });

  test('a loop without turntables is not on a turntable loop', () {
    final decision = decide(250, on: east);
    expect(decision.isHit, isFalse);
    expect(decision.turn, isNull);
    expect(
      decision.describe(tramLabel: 'AUTO', keyLabel: 'SHIFT'),
      'AUTO SHIFT: not on a turntable loop -> MISS',
    );
  });

  test('with several discs the nearest one is named on a miss', () {
    final far = TurntableTurn.build(
      from: north,
      to: east,
      center: const Point(0.0, -200.0),
    );
    final two = TurntableSwitchSystem([turn, far]);
    final decision = two.decide(
      path: north,
      distance: 100,
      speed: 150,
      halfLength: 28,
    );
    expect(decision.turn, same(turn), reason: 'offset -200 vs. -400');
  });
}
