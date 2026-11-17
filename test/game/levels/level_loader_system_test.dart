import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_data.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_loader_system.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_graph.dart';

void main() {
  test(
    'emits zero hazards for closed loops and builds crossovers and systems',
    () {
      final level = LevelData.fromJson({
        'id': 'closed_loops',
        'bounds': {'width': 1040, 'height': 680},
        'segments': [
          {
            'id': 'ns',
            'end': 'connected',
            'nextSegment': 'ns',
            'points': [
              [0, 200],
              [0, -200],
              [200, -200],
              [200, 200],
              [0, 200],
            ],
          },
          {
            'id': 'ew',
            'end': 'connected',
            'nextSegment': 'ew',
            'points': [
              [-200, 0],
              [200, 0],
              [200, 200],
              [-200, 200],
              [-200, 0],
            ],
          },
        ],
        'spawns': [
          {'segment': 'ns', 'time': 0, 'speed': 140, 'startDistance': 50},
        ],
        'goal': {'crashes': 1},
        'crossovers': [
          {
            'id': 'sw_mid',
            'platformShape': 'circle',
            'x': 0,
            'y': 0,
            'links': [
              {'from': 'ns', 'to': 'ew'},
            ],
          },
        ],
      });

      final runtime = const LevelLoaderSystem().load(level);
      expect(runtime.paths.keys, containsAll(['ns', 'ew']));
      expect(runtime.crossovers, hasLength(1));
      expect(runtime.switches.turns, isNotEmpty);
      expect(runtime.scoreSystem.crashGoal, 1);
      expect(runtime.spawnSystem.pendingCount, 1);
      expect(runtime.hazards, isEmpty);
    },
  );

  test(
    'extracts forward hazards and unconnected start deadEnds on open segments',
    () {
      final level = LevelData.fromJson({
        'id': 'open_hazards',
        'bounds': {'width': 1040, 'height': 680},
        'segments': [
          {
            'id': 'entry',
            'end': 'connected',
            'nextSegment': 'river_spur',
            'points': [
              [-300, 0],
              [0, 0],
            ],
          },
          {
            'id': 'river_spur',
            'end': 'river',
            'points': [
              [0, 0],
              [200, 0],
            ],
          },
          {
            'id': 'work_spur',
            'end': 'construction',
            'points': [
              [0, 100],
              [0, -100],
            ],
          },
        ],
        'spawns': [
          {'segment': 'entry', 'time': 0, 'speed': 120},
        ],
        'goal': {'crashes': 2},
      });

      final runtime = const LevelLoaderSystem().load(level);
      // `entry` has no incoming segment -> start deadEnd at (-300, 0), heading south (pi/2 + pi).
      // `river_spur` has `entry` incoming -> only forward river hazard at (200, 0).
      // `work_spur` has neither -> forward construction at (0, -100) + start deadEnd at (0, 100).
      expect(runtime.hazards, hasLength(4));

      final river = runtime.hazards.singleWhere(
        (h) => h.kind == TrackEnd.river,
      );
      expect(river.position.x, closeTo(200, 0.01));
      expect(river.position.y, closeTo(0, 0.01));
      expect(river.headingRad, closeTo(math.pi / 2, 0.01));

      final construction = runtime.hazards.singleWhere(
        (h) => h.kind == TrackEnd.construction,
      );
      expect(construction.position.x, closeTo(0, 0.01));
      expect(construction.position.y, closeTo(-100, 0.01));
      expect(construction.headingRad, closeTo(0, 0.01));

      final deadEnds = runtime.hazards
          .where((h) => h.kind == TrackEnd.deadEnd)
          .toList();
      expect(deadEnds, hasLength(2));
    },
  );
}
