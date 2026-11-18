import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/gate_data.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/crash_system.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/gate_system.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_graph.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_path.dart';

TramPose _pose({
  required int index,
  required double distance,
  double speed = 100,
  String segmentId = 'main',
  bool isCrashed = false,
  bool isRidingTurntable = false,
}) => (
  index: index,
  label: 'T$index',
  segmentId: segmentId,
  trackDistance: distance,
  speed: speed,
  position: math.Point(distance, 0.0),
  heading: math.pi / 2,
  isRidingTurntable: isRidingTurntable,
  isCrashed: isCrashed,
);

void main() {
  late TrackPath mainPath;
  late GateSystem system;

  setUp(() {
    mainPath = TrackPath([
      const math.Point(0.0, 0.0),
      const math.Point(400.0, 0.0),
    ], name: 'main');
    system = GateSystem(
      gates: const [GateData(id: 'g1', x: 200, y: 0)],
      paths: {'main': mainPath},
    );
  });

  test('resolves gate on track path and starts open', () {
    expect(system.gates, hasLength(1));
    final gate = system.gates.single;
    expect(gate.baseSegmentId, 'main');
    expect(gate.along, closeTo(200.0, 0.001));
    expect(gate.isClosed, isFalse);
  });

  test(
    'auto-closes and emits callback after tram 1 enters and exits pass zone',
    () {
      final closed = <GateInstance>[];

      // Inside pass zone (<= 30 px from 200.0): gate stays open.
      expect(
        system.step([
          _pose(index: 0, distance: 170.0),
        ], onAutoClosed: closed.add),
        isEmpty,
      );
      expect(system.gates.single.isClosed, isFalse);
      expect(closed, isEmpty);

      // Exits pass zone (> 30 px past 200.0): gate closes and fires callback.
      expect(
        system.step([
          _pose(index: 0, distance: 231.0),
        ], onAutoClosed: closed.add),
        isEmpty,
      );
      expect(system.gates.single.isClosed, isTrue);
      expect(closed, hasLength(1));
      expect(closed.single.data.id, 'g1');
    },
  );

  test('emits deadEnd CrashEvent when tram 2 hits closed barrier zone', () {
    system.step([_pose(index: 0, distance: 200.0)]);
    system.step([_pose(index: 0, distance: 235.0)]);
    expect(system.gates.single.isClosed, isTrue);

    // Outside 18 px hit zone: no crash.
    expect(system.step([_pose(index: 1, distance: 181.0)]), isEmpty);

    // Inside 18 px hit zone: deadEnd crash at gate centre.
    final crashes = system.step([_pose(index: 1, distance: 182.0)]);
    expect(crashes, hasLength(1));
    expect(crashes.single.tramIndices, [1]);
    expect(crashes.single.hazard, TrackEnd.deadEnd);
    expect(crashes.single.position, const math.Point(200.0, 0.0));
  });

  test('tryOpen handles approaching, stopped, and out-of-window bounds', () {
    system.step([_pose(index: 0, distance: 200.0)]);
    system.step([_pose(index: 0, distance: 235.0)]);
    expect(system.gates.single.isClosed, isTrue);

    // Outside approaching window (ahead > 120 and ahead < -18): refused.
    expect(
      system.tryOpen(path: mainPath, distance: 79.0, speed: 100.0),
      isNull,
    );
    expect(
      system.tryOpen(path: mainPath, distance: 219.0, speed: 100.0),
      isNull,
    );
    // Outside stopped radius (> 96 px): refused.
    expect(system.tryOpen(path: mainPath, distance: 103.0, speed: 0.0), isNull);
    expect(system.gates.single.isClosed, isTrue);

    // Approaching within [-18, 120] px: opens gate.
    final openedApproach = system.tryOpen(
      path: mainPath,
      distance: 80.0,
      speed: 100.0,
    );
    expect(openedApproach, isNotNull);
    expect(system.gates.single.isClosed, isFalse);

    // Tram 2 passes through and exits: gate auto-closes again.
    system.step([_pose(index: 1, distance: 200.0)]);
    system.step([_pose(index: 1, distance: 235.0)]);
    expect(system.gates.single.isClosed, isTrue);

    // Stopped within 96 px: opens gate.
    final openedStopped = system.tryOpen(
      path: mainPath,
      distance: 104.0,
      speed: 0.0,
    );
    expect(openedStopped, isNotNull);
    expect(system.gates.single.isClosed, isFalse);
  });
}
