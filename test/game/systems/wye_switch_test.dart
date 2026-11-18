import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_path.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_movement.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_switch_system.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_turn_builder.dart';
import 'package:super_hot_imperfect_form_trams/input/tram_controls.dart';

void main() {
  group('TramControls.turnSteerFor', () {
    test('wasd maps A/D independently of W and cancels when both or none', () {
      expect(TramControls.wasd.turnSteerFor({LogicalKeyboardKey.keyA}), -1.0);
      expect(TramControls.wasd.turnSteerFor({LogicalKeyboardKey.keyD}), 1.0);
      expect(
        TramControls.wasd.turnSteerFor({
          LogicalKeyboardKey.keyW,
          LogicalKeyboardKey.keyA,
        }),
        -1.0,
      );
      expect(
        TramControls.wasd.turnSteerFor({
          LogicalKeyboardKey.keyW,
          LogicalKeyboardKey.keyD,
        }),
        1.0,
      );
      expect(
        TramControls.wasd.turnSteerFor({
          LogicalKeyboardKey.keyA,
          LogicalKeyboardKey.keyD,
        }),
        0.0,
      );
      expect(TramControls.wasd.turnSteerFor({LogicalKeyboardKey.keyW}), 0.0);
      expect(TramControls.wasd.turnSteerFor(const {}), 0.0);
    });

    test('arrows maps Left/Right independently of Up', () {
      expect(
        TramControls.arrows.turnSteerFor({LogicalKeyboardKey.arrowLeft}),
        -1.0,
      );
      expect(
        TramControls.arrows.turnSteerFor({LogicalKeyboardKey.arrowRight}),
        1.0,
      );
      expect(
        TramControls.arrows.turnSteerFor({
          LogicalKeyboardKey.arrowUp,
          LogicalKeyboardKey.arrowLeft,
        }),
        -1.0,
      );
      expect(
        TramControls.arrows.turnSteerFor({
          LogicalKeyboardKey.arrowUp,
          LogicalKeyboardKey.arrowRight,
        }),
        1.0,
      );
      expect(
        TramControls.arrows.turnSteerFor({
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.arrowRight,
        }),
        0.0,
      );
    });
  });

  group('Wye curve turnout (TurntableTurnBuilder + SwitchSystem + Ride)', () {
    late TrackPath vert;
    late TrackPath horiz;
    late TurntableSwitchSystem switchSystem;

    setUp(() {
      vert = TrackPath([
        const math.Point(0.0, 200.0),
        const math.Point(0.0, -200.0),
      ], name: 'vert');
      horiz = TrackPath([
        const math.Point(-200.0, 0.0),
        const math.Point(200.0, 0.0),
      ], name: 'horiz');
      final turns = TurntableTurnBuilder.buildAll(
        from: vert,
        to: horiz,
        center: const math.Point(0.0, 0.0),
        radius: 32,
        movement: TurntableMovement.curve,
      );
      switchSystem = TurntableSwitchSystem(turns);
    });

    test('turnSteer -1 selects -90° left curve and lands on exitPath', () {
      final decision = switchSystem.decide(
        path: vert,
        distance: 190.0,
        speed: 120.0,
        halfLength: 28.0,
        turnSteer: -1.0,
      );

      expect(decision.isHit, isTrue);
      expect(decision.turn!.sweep, closeTo(-math.pi / 2, 0.01));
      final ride = decision.ride!;
      expect(ride.exitPath, same(horiz.reversed));

      for (var i = 0; !ride.finished && i < 600; i++) {
        ride.advance(1 / 60, 120.0);
      }
      expect(ride.finished, isTrue);
      expect(
        ride.position.distanceTo(ride.exitPath.positionAt(ride.exitDistance)),
        lessThanOrEqualTo(0.5),
      );
    });

    test('turnSteer +1 selects +90° right curve and lands on exitPath', () {
      final decision = switchSystem.decide(
        path: vert,
        distance: 190.0,
        speed: 120.0,
        halfLength: 28.0,
        turnSteer: 1.0,
      );

      expect(decision.isHit, isTrue);
      expect(decision.turn!.sweep, closeTo(math.pi / 2, 0.01));
      final ride = decision.ride!;
      expect(ride.exitPath, same(horiz));

      for (var i = 0; !ride.finished && i < 600; i++) {
        ride.advance(1 / 60, 120.0);
      }
      expect(ride.finished, isTrue);
      expect(
        ride.position.distanceTo(ride.exitPath.positionAt(ride.exitDistance)),
        lessThanOrEqualTo(0.5),
      );
    });

    test('SHIFT alone without steer or desiredDirection misses', () {
      final decision = switchSystem.decide(
        path: vert,
        distance: 190.0,
        speed: 120.0,
        halfLength: 28.0,
        turnSteer: 0.0,
        desiredDirection: null,
      );

      expect(decision.isHit, isFalse);
      expect(decision.ride, isNull);
    });
  });
}
