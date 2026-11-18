import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_data.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_loader_system.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_repository.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/prop_data.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_graph.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_path.dart';
import 'package:super_hot_imperfect_form_trams/game/tram_game.dart';

void _expectBuildingsClearOfTracks(LevelData level) {
  final paths = [
    for (final seg in level.segments)
      if (seg.points.length >= 2) TrackPath(seg.points, name: seg.id),
  ];
  for (final prop in level.props.where((p) => p.type == PropType.building)) {
    final guarded = Rect.fromCenter(
      center: Offset(prop.x, prop.y),
      width: prop.width,
      height: prop.height,
    ).inflate(20);
    for (final path in paths) {
      final steps = (path.length / 8).ceil();
      for (var i = 0; i <= steps; i++) {
        final d = math.min(i * 8.0, path.length);
        final pt = path.positionAt(d);
        expect(
          guarded.contains(Offset(pt.x, pt.y)),
          isFalse,
          reason:
              '${level.id}: building (${prop.x},${prop.y}) too close to '
              '${path.name} at (${pt.x},${pt.y})',
        );
      }
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('manifest contains both Budapest campaign levels and example', () async {
    final levels = await LevelRepository().loadAll();
    expect(levels.map((l) => l.id).toList(), [
      'budapest_01_rakpart_csapda',
      'budapest_02_epitkezes_tolatas',
      'example_two_loops',
    ]);
    for (final level in levels) {
      final runtime = const LevelLoaderSystem().load(level);
      expect(runtime.switches.turns, isNotEmpty);
      _expectBuildingsClearOfTracks(level);
    }
  });

  test('campaign levels expose expected TrackEnd hazards only', () async {
    final repo = LevelRepository();
    final lvl1 = await repo.load('budapest_01_rakpart_csapda');
    final rt1 = const LevelLoaderSystem().load(lvl1);
    expect(rt1.hazards.map((h) => h.kind).toList(), [TrackEnd.river]);

    final lvl2 = await repo.load('budapest_02_epitkezes_tolatas');
    final rt2 = const LevelLoaderSystem().load(lvl2);
    expect(rt2.hazards.map((h) => h.kind).toSet(), {
      TrackEnd.deadEnd,
      TrackEnd.construction,
    });
    expect(rt2.hazards.length, 2);
  });

  for (final id in const [
    'budapest_01_rakpart_csapda',
    'budapest_02_epitkezes_tolatas',
  ]) {
    testWidgets('$id stays crash-free during 10s with zero player input', (
      tester,
    ) async {
      final level = await tester.runAsync(() => LevelRepository().load(id));
      final game = TramGame(initialLevel: level);
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await tester.pump();
      await tester.pump();

      for (var i = 0; i < 200; i++) {
        game.update(0.05);
      }
      expect(game.scoreSystem.crashCount, 0);
      expect(game.scoreSystem.isGoalMet, isFalse);
    });
  }
}
