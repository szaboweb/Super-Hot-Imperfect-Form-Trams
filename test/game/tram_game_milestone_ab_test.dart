import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/components/crash_effect_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/hazard_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/smoke_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/spark_effect_component.dart';
import 'package:super_hot_imperfect_form_trams/game/graphics/render_layer.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_data.dart';
import 'package:super_hot_imperfect_form_trams/game/tram_game.dart';

void main() {
  testWidgets('AI tram maintains cruise speed against drag over 3.0s', (
    tester,
  ) async {
    final level = LevelData.fromJson({
      'id': 'ai_cruise',
      'bounds': {'width': 1040, 'height': 680},
      'segments': const [
        {
          'id': 'loop_a',
          'end': 'connected',
          'nextSegment': 'loop_a',
          'points': [
            [-200, -100],
            [200, -100],
            [200, 100],
            [-200, 100],
            [-200, -100],
          ],
        },
      ],
      'spawns': const [
        {'segment': 'loop_a', 'time': 0, 'speed': 160, 'startDistance': 0},
      ],
      'goal': const {'crashes': 1},
    });
    final game = TramGame(initialLevel: level);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump();

    for (var i = 0; i < 60; i++) {
      game.update(0.05);
    }

    expect(game.trams.single.speed, greaterThan(130));
  });

  testWidgets('AI tram switches onto safe loop before open river hazard', (
    tester,
  ) async {
    final level = LevelData.fromJson({
      'id': 'ai_evade_river',
      'bounds': {'width': 1040, 'height': 680},
      'segments': const [
        {
          'id': 'spur_river',
          'end': 'river',
          'points': [
            [-200, 0],
            [150, 0],
          ],
        },
        {
          'id': 'safe_loop',
          'end': 'connected',
          'nextSegment': 'safe_loop',
          'points': [
            [0, 200],
            [0, -200],
            [200, -200],
            [200, 200],
            [0, 200],
          ],
        },
      ],
      'spawns': const [
        {
          'segment': 'spur_river',
          'time': 0,
          'speed': 150,
          'startDistance': 140,
        },
      ],
      'crossovers': const [
        {
          'id': 'sw_escape',
          'platformShape': 'circle',
          'x': 0,
          'y': 0,
          'links': [
            {'from': 'spur_river', 'to': 'safe_loop'},
          ],
        },
      ],
      'goal': const {'crashes': 1},
    });
    final game = TramGame(initialLevel: level);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump();

    for (var i = 0; i < 30; i++) {
      game.update(0.05);
    }

    expect(game.trams.single.isCrashed, isFalse);
    expect(game.trams.single.path.name, 'safe_loop');
  });

  testWidgets('river crash sinks tram to depth layer, spawns FX, and shakes', (
    tester,
  ) async {
    final level = LevelData.fromJson({
      'id': 'river_plunge',
      'bounds': {'width': 1040, 'height': 680},
      'segments': const [
        {
          'id': 'river_spur',
          'end': 'river',
          'points': [
            [-100, 0],
            [100, 0],
          ],
        },
      ],
      'spawns': const [
        {
          'segment': 'river_spur',
          'time': 0,
          'speed': 160,
          'startDistance': 185,
        },
      ],
      'goal': const {'crashes': 1},
    });
    final game = TramGame(initialLevel: level);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump();

    game.update(0.2);
    expect(game.camera.viewfinder.position.length, greaterThan(0));
    game.update(0.05);

    final tram = game.trams.single;
    expect(tram.isCrashed, isTrue);
    expect(tram.priority, RenderLayer.depth.priority + 5);
    expect(tram.scale.x, lessThan(1.0));
    expect(game.world.children.whereType<CrashEffectComponent>(), isNotEmpty);

    game.update(0.35);
    expect(game.camera.viewfinder.position, Vector2.zero());
  });

  testWidgets('mounts HazardComponent, SmokeComponent, and SHIFT sparks', (
    tester,
  ) async {
    final level = LevelData.fromJson({
      'id': 'fx_world',
      'bounds': {'width': 1040, 'height': 680},
      'segments': const [
        {
          'id': 'spur_dead',
          'end': 'deadEnd',
          'points': [
            [0, 200],
            [0, -200],
          ],
        },
        {
          'id': 'ew_loop',
          'end': 'connected',
          'nextSegment': 'ew_loop',
          'points': [
            [-200, 0],
            [200, 0],
            [200, 200],
            [-200, 200],
            [-200, 0],
          ],
        },
      ],
      'spawns': const [
        {
          'segment': 'spur_dead',
          'time': 0,
          'speed': 120,
          'startDistance': 170,
          'controls': 'wasd',
        },
      ],
      'crossovers': const [
        {
          'id': 'sw_mid',
          'platformShape': 'circle',
          'x': 0,
          'y': 0,
          'links': [
            {'from': 'spur_dead', 'to': 'ew_loop'},
          ],
        },
      ],
      'goal': const {'crashes': 1},
    });
    final game = TramGame(initialLevel: level);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump();

    expect(game.world.children.whereType<HazardComponent>(), isNotEmpty);
    expect(game.world.children.whereType<SmokeComponent>(), hasLength(1));

    expect(game.trams.single.requestTurn(), isTrue);
    game.update(0.01);
    expect(game.world.children.whereType<SparkEffectComponent>(), isNotEmpty);
  });
}
