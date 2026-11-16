import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/crash_system.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_graph.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_path.dart';

void main() {
  TramPose pose(
    int index, {
    String seg = 'loop',
    double d = 10,
    double speed = 100,
    double x = 0,
    double y = 0,
    double heading = math.pi / 2,
    bool riding = false,
    bool crashed = false,
  }) => (
    index: index,
    label: 'tram_$index',
    segmentId: seg,
    trackDistance: d,
    speed: speed,
    position: math.Point(x, y),
    heading: heading,
    isRidingTurntable: riding,
    isCrashed: crashed,
  );

  TrackPath closedLoop(String id) => TrackPath(const [
    math.Point(0, 0),
    math.Point(200, 0),
    math.Point(200, 200),
    math.Point(0, 200),
    math.Point(0, 0),
  ], name: id);

  TrackPath openLine(
    String id, {
    double x0 = 0,
    double x1 = 100,
    double y = 0,
  }) => TrackPath([math.Point(x0, y), math.Point(x1, y)], name: id);

  CrashSystem makeSystem(
    List<TrackSegment> segments,
    Map<String, TrackPath> paths, {
    double tramLength = 56,
    double tramWidth = 20,
  }) => CrashSystem(
    graph: TrackGraph(segments: segments),
    paths: paths,
    tramLength: tramLength,
    tramWidth: tramWidth,
  );

  CrashSystem loopSystem({double tramLength = 56, double tramWidth = 20}) =>
      makeSystem(
        const [TrackSegment(id: 'loop')],
        {'loop': closedLoop('loop')},
        tramLength: tramLength,
        tramWidth: tramWidth,
      );

  group('pairwise 2D capsule collision', () {
    test('head-on trams collide below 56 px center gap and clear at 56 px', () {
      final sys = loopSystem();
      final clear = sys.step([
        pose(0, x: 0, y: 0, heading: math.pi / 2),
        pose(1, x: 56, y: 0, heading: -math.pi / 2),
      ]);
      expect(clear.crashes, isEmpty);

      final hit = sys.step([
        pose(0, x: 0, y: 0, heading: math.pi / 2),
        pose(1, x: 55.5, y: 0, heading: -math.pi / 2),
      ]);
      expect(hit.crashes, hasLength(1));
      expect(hit.crashes.single.hazard, isNull);
      expect(hit.crashes.single.tramIndices, [0, 1]);
      expect(hit.crashes.single.position, const math.Point(27.75, 0.0));
    });

    test('90-degree T-bone collides when nose enters 20 px of flank', () {
      final sys = loopSystem();
      final clear = sys.step([
        pose(0, x: 0, y: 0, heading: math.pi / 2),
        pose(1, x: 0, y: 38, heading: 0),
      ]);
      expect(clear.crashes, isEmpty);

      final hit = sys.step([
        pose(0, x: 0, y: 0, heading: math.pi / 2),
        pose(1, x: 0, y: 37.5, heading: 0),
      ]);
      expect(hit.crashes, hasLength(1));
      expect(hit.crashes.single.hazard, isNull);
      expect(hit.crashes.single.tramIndices, [0, 1]);
    });

    test('parallel lanes 60 px apart do not collide', () {
      final sys = loopSystem();
      final clear = sys.step([
        pose(0, x: 100, y: 0, heading: math.pi / 2),
        pose(1, x: 100, y: 60, heading: math.pi / 2),
      ]);
      expect(clear.crashes, isEmpty);

      final closeOpposite = sys.step([
        pose(0, x: 100, y: 0, heading: math.pi / 2),
        pose(1, x: 100, y: 19, heading: -math.pi / 2),
      ]);
      expect(closeOpposite.crashes, hasLength(1));
    });

    test('handles zero-spine capsule when tramLength equals tramWidth', () {
      final sys = loopSystem(tramLength: 20, tramWidth: 20);
      expect(sys.step([pose(0), pose(1, x: 19)]).crashes, hasLength(1));
      expect(sys.step([pose(0), pose(1, x: 20)]).crashes, isEmpty);
    });

    test('skips already crashed trams and still collides turntable riders', () {
      final sys = loopSystem();
      final ignored = sys.step([pose(0, crashed: true), pose(1, x: 5)]);
      expect(ignored.crashes, isEmpty);

      final riderHit = sys.step([pose(0, riding: true), pose(1, x: 10)]);
      expect(riderHit.crashes, hasLength(1));
      expect(riderHit.crashes.single.tramIndices, [0, 1]);
    });
  });

  group('open-segment hazards and transitions', () {
    test('detects deadEnd, river, construction, and start deadEnd hazards', () {
      final sys = makeSystem(
        const [
          TrackSegment(id: 'seg_dead', end: TrackEnd.deadEnd),
          TrackSegment(id: 'seg_river', end: TrackEnd.river),
          TrackSegment(id: 'seg_work', end: TrackEnd.construction),
        ],
        {
          'seg_dead': openLine('seg_dead', y: 0),
          'seg_river': openLine('seg_river', y: 100),
          'seg_work': openLine('seg_work', y: 200),
        },
      );

      final res = sys.step([
        pose(0, seg: 'seg_dead', d: 101, x: 100, y: 0),
        pose(1, seg: 'seg_river', d: 100, x: 100, y: 100),
        pose(2, seg: 'seg_work', d: 102, x: 100, y: 200),
        pose(3, seg: 'seg_river', d: -1, x: 0, y: 100),
      ]);

      expect(res.crashes, hasLength(4));
      expect(res.crashes.map((c) => c.hazard).toList(), [
        TrackEnd.deadEnd,
        TrackEnd.river,
        TrackEnd.construction,
        TrackEnd.deadEnd,
      ]);
      expect(
        res.crashes[1].description,
        'tram_1 crashed into river on seg_river',
      );
    });

    test('skips pairwise check for tram that hit hazard in same step', () {
      final sys = makeSystem(
        const [
          TrackSegment(id: 'spur', end: TrackEnd.river),
          TrackSegment(id: 'loop'),
        ],
        {'spur': openLine('spur'), 'loop': closedLoop('loop')},
      );

      final res = sys.step([
        pose(0, seg: 'spur', d: 101, x: 100, y: 0),
        pose(1, seg: 'loop', d: 100, x: 105, y: 0),
      ]);
      expect(res.crashes, hasLength(1));
      expect(res.crashes.single.tramIndices, [0]);
      expect(res.crashes.single.hazard, TrackEnd.river);
    });

    test('handles _rev open segments for start deadEnd and forward hazard', () {
      final sys = makeSystem(
        const [TrackSegment(id: 'spur', end: TrackEnd.construction)],
        {'spur': openLine('spur')},
      );

      final startHit = sys.step([pose(0, seg: 'spur_rev', d: 100, x: 0)]);
      expect(startHit.crashes, hasLength(1));
      expect(startHit.crashes.single.hazard, TrackEnd.deadEnd);

      final forwardHit = sys.step([pose(1, seg: 'spur_rev', d: -0.5, x: 100)]);
      expect(forwardHit.crashes, hasLength(1));
      expect(forwardHit.crashes.single.hazard, TrackEnd.construction);
      expect(
        forwardHit.crashes.single.description,
        'tram_1 crashed into construction on spur',
      );
    });

    test('emits TrackEnd.connected transitions for forward and _rev paths', () {
      final sys = makeSystem(
        const [
          TrackSegment(id: 'seg_a', nextSegment: 'seg_b'),
          TrackSegment(id: 'seg_b', end: TrackEnd.river),
        ],
        {
          'seg_a': openLine('seg_a', x0: 0, x1: 100),
          'seg_b': openLine('seg_b', x0: 100, x1: 300),
        },
      );

      final fwd = sys.step([pose(0, seg: 'seg_a', d: 103.5, x: 100)]);
      expect(fwd.crashes, isEmpty);
      expect(fwd.transitions, hasLength(1));
      expect(fwd.transitions.single.tramIndex, 0);
      expect(fwd.transitions.single.nextPath.name, 'seg_b');
      expect(fwd.transitions.single.nextDistance, closeTo(3.5, 1e-9));

      final rev = sys.step([
        pose(1, seg: 'seg_a_rev', d: -2.5, speed: -80, x: 100),
      ]);
      expect(rev.crashes, isEmpty);
      expect(rev.transitions, hasLength(1));
      expect(rev.transitions.single.nextPath.name, 'seg_b_rev');
      expect(rev.transitions.single.nextDistance, closeTo(197.5, 1e-9));
    });

    test('emits TrackEnd.connected transition along plain nextSegment', () {
      final sys = makeSystem(
        const [
          TrackSegment(id: 'seg_a', nextSegment: 'seg_b'),
          TrackSegment(id: 'seg_b', end: TrackEnd.deadEnd),
        ],
        {
          'seg_a': openLine('seg_a', x0: 0, x1: 80),
          'seg_b': openLine('seg_b', x0: 80, x1: 200),
        },
      );

      final res = sys.step([pose(0, seg: 'seg_a', d: 82.25, x: 80)]);
      expect(res.crashes, isEmpty);
      expect(res.transitions, hasLength(1));
      expect(res.transitions.single.nextPath.name, 'seg_b');
      expect(res.transitions.single.nextDistance, closeTo(2.25, 1e-9));
    });

    test('ignores turntable riders and unknown segment ids on open checks', () {
      final sys = makeSystem(
        const [TrackSegment(id: 'spur', end: TrackEnd.river)],
        {'spur': openLine('spur')},
      );

      final res = sys.step([
        pose(0, seg: 'spur', d: 150, riding: true),
        pose(1, seg: 'missing', d: 150, x: 500, y: 500),
      ]);
      expect(res.crashes, isEmpty);
      expect(res.transitions, isEmpty);
    });
  });
}
