import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_graph.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_path.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/tram_ai_system.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_movement.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_switch_system.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_turn.dart';

TrackPath _closedLoop(String name, double yOffset) => TrackPath([
  math.Point(-200, yOffset),
  math.Point(200, yOffset),
  math.Point(200, yOffset + 200),
  math.Point(-200, yOffset + 200),
  math.Point(-200, yOffset),
], name: name);

void main() {
  test(
    'cruise throttle holds positive and negative cruise speeds against drag',
    () {
      final loop = _closedLoop('loop_a', 0);
      final graph = TrackGraph(
        segments: const [
          TrackSegment(
            id: 'loop_a',
            end: TrackEnd.connected,
            nextSegment: 'loop_a',
          ),
        ],
      );
      final ai = TramAiSystem(
        graph: graph,
        paths: {'loop_a': loop},
        switches: const TurntableSwitchSystem([]),
      );

      var forwardSpeed = 160.0;
      var reverseSpeed = -90.0;
      const dt = 0.02;
      for (var i = 0; i < 150; i++) {
        final cmds = ai.step(dt, [
          (
            index: 0,
            path: loop,
            trackDistance: 100,
            speed: forwardSpeed,
            cruiseSpeed: 160,
            isPlayerControlled: false,
            isRidingTurntable: false,
            isCrashed: false,
            position: const math.Point(0, 0),
          ),
          (
            index: 1,
            path: loop,
            trackDistance: 300,
            speed: reverseSpeed,
            cruiseSpeed: -90,
            isPlayerControlled: false,
            isRidingTurntable: false,
            isCrashed: false,
            position: const math.Point(0, 200),
          ),
        ]);
        forwardSpeed +=
            cmds[0]!.throttle * TramAiSystem.vehicleAcceleration * dt;
        forwardSpeed *= math.pow(TramAiSystem.vehicleDrag, dt).toDouble();
        reverseSpeed +=
            cmds[1]!.throttle * TramAiSystem.vehicleAcceleration * dt;
        reverseSpeed *= math.pow(TramAiSystem.vehicleDrag, dt).toDouble();
      }

      expect(forwardSpeed, closeTo(160, 1.5));
      expect(reverseSpeed, closeTo(-90, 1.5));
    },
  );

  test('skips player-controlled, crashed, zero-cruise, and riding trams', () {
    final loop = _closedLoop('loop_a', 0);
    final ai = TramAiSystem(
      graph: TrackGraph(segments: const []),
      paths: {'loop_a': loop},
      switches: const TurntableSwitchSystem([]),
    );
    final cmds = ai.step(0.1, [
      (
        index: 0,
        path: loop,
        trackDistance: 0,
        speed: 120,
        cruiseSpeed: 160,
        isPlayerControlled: true,
        isRidingTurntable: false,
        isCrashed: false,
        position: const math.Point(0, 0),
      ),
      (
        index: 1,
        path: loop,
        trackDistance: 50,
        speed: 0,
        cruiseSpeed: 160,
        isPlayerControlled: false,
        isRidingTurntable: false,
        isCrashed: true,
        position: const math.Point(0, 0),
      ),
      (
        index: 2,
        path: loop,
        trackDistance: 80,
        speed: 120,
        cruiseSpeed: 160,
        isPlayerControlled: false,
        isRidingTurntable: true,
        isCrashed: false,
        position: const math.Point(0, 0),
      ),
    ]);
    expect(cmds, isEmpty);
  });

  test(
    'evades open river hazard via safe turntable and panic-brakes when trapped',
    () {
      final spur = TrackPath(const [
        math.Point(-200, 0),
        math.Point(200, 0),
      ], name: 'river_spur');
      final safeLoop = TrackPath(const [
        math.Point(0, -200),
        math.Point(0, 200),
        math.Point(200, 200),
        math.Point(200, -200),
        math.Point(0, -200),
      ], name: 'safe_loop');
      final escapeTurn = TurntableTurn.build(
        from: spur,
        to: safeLoop,
        center: const math.Point(0, 0),
      );
      final ai = TramAiSystem(
        graph: TrackGraph(
          segments: const [
            TrackSegment(id: 'river_spur', end: TrackEnd.river),
            TrackSegment(
              id: 'safe_loop',
              end: TrackEnd.connected,
              nextSegment: 'safe_loop',
            ),
          ],
        ),
        paths: {'river_spur': spur, 'safe_loop': safeLoop},
        switches: TurntableSwitchSystem([escapeTurn]),
      );

      final evade = ai.step(0.05, [
        (
          index: 0,
          path: spur,
          trackDistance: 240,
          speed: 150,
          cruiseSpeed: 150,
          isPlayerControlled: false,
          isRidingTurntable: false,
          isCrashed: false,
          position: const math.Point(40, 0),
        ),
      ]);
      expect(evade[0]!.shouldTurn, isTrue);
      expect(evade[0]!.desiredDirection, isNotNull);

      final trapped = ai.step(0.05, [
        (
          index: 0,
          path: spur,
          trackDistance: 350,
          speed: 150,
          cruiseSpeed: 150,
          isPlayerControlled: false,
          isRidingTurntable: false,
          isCrashed: false,
          position: const math.Point(150, 0),
        ),
      ]);
      expect(trapped[0]!.shouldTurn, isFalse);
      expect(trapped[0]!.throttle, -1.0);
    },
  );

  test(
    'patrol prefers loop with active player and ignores reverse Y-turns',
    () {
      final loopA = _closedLoop('loop_a', 0);
      final loopB = _closedLoop('loop_b', 60);
      final slideToB = TurntableTurn.build(
        from: loopA,
        to: loopB,
        center: const math.Point(0, 30),
        movement: TurntableMovement.slide,
      );
      final yReverse = TurntableTurn.build(
        from: loopA,
        to: loopA,
        center: const math.Point(0, 0),
        movement: TurntableMovement.reverse,
      );
      final ai = TramAiSystem(
        graph: TrackGraph(
          segments: const [
            TrackSegment(
              id: 'loop_a',
              end: TrackEnd.connected,
              nextSegment: 'loop_a',
            ),
            TrackSegment(
              id: 'loop_b',
              end: TrackEnd.connected,
              nextSegment: 'loop_b',
            ),
          ],
        ),
        paths: {'loop_a': loopA, 'loop_b': loopB},
        switches: TurntableSwitchSystem([yReverse, slideToB]),
        patrolSwitchIntervalSec: 4.0,
      );

      final first = ai.step(0.1, [
        (
          index: 0,
          path: loopA,
          trackDistance: 200,
          speed: 140,
          cruiseSpeed: 140,
          isPlayerControlled: false,
          isRidingTurntable: false,
          isCrashed: false,
          position: const math.Point(0, 0),
        ),
        (
          index: 1,
          path: loopB,
          trackDistance: 100,
          speed: 140,
          cruiseSpeed: 0,
          isPlayerControlled: true,
          isRidingTurntable: false,
          isCrashed: false,
          position: const math.Point(-100, 60),
        ),
      ]);
      expect(first[0]!.shouldTurn, isTrue);

      final onCooldown = ai.step(1.0, [
        (
          index: 0,
          path: loopA,
          trackDistance: 200,
          speed: 140,
          cruiseSpeed: 140,
          isPlayerControlled: false,
          isRidingTurntable: false,
          isCrashed: false,
          position: const math.Point(0, 0),
        ),
      ]);
      expect(onCooldown[0]!.shouldTurn, isFalse);
    },
  );
}
