import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_grid.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_level_builder.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_piece.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_data.dart';
import 'package:super_hot_imperfect_form_trams/game/tram_game.dart';
import 'package:super_hot_imperfect_form_trams/ui/screens/race_screen.dart';

LevelData _loopLevel({
  double width = 1040,
  double height = 680,
  String end = 'connected',
  List<List<double>>? points,
  List<Map<String, dynamic>>? spawns,
  int crashes = 1,
}) {
  final pts =
      points ??
      const [
        [-200, -100],
        [200, -100],
        [200, 100],
        [-200, 100],
        [-200, -100],
      ];
  return LevelData.fromJson({
    'id': 'test_level',
    'bounds': {'width': width, 'height': height},
    'segments': [
      {
        'id': 'seg_a',
        'end': end,
        if (end == 'connected') 'nextSegment': 'seg_a',
        'points': pts,
      },
    ],
    'spawns':
        spawns ??
        const [
          {'segment': 'seg_a', 'time': 0, 'speed': 60, 'startDistance': 0},
        ],
    'goal': {'crashes': crashes},
  });
}

void main() {
  testWidgets('TramGame loads a runtime LevelData directly', (tester) async {
    final grid = EditorGrid()
      ..place(EditorPiece.cornerSE, (col: 1, row: 1))
      ..place(EditorPiece.cornerSW, (col: 2, row: 1))
      ..place(EditorPiece.straightV, (col: 1, row: 2))
      ..place(EditorPiece.straightV, (col: 2, row: 2))
      ..place(EditorPiece.switchRectangle, (col: 2, row: 2))
      ..place(EditorPiece.cornerNE, (col: 1, row: 3))
      ..place(EditorPiece.cornerNW, (col: 2, row: 3))
      ..place(EditorPiece.tramGreen, (col: 1, row: 1))
      ..place(EditorPiece.cornerSE, (col: 3, row: 1))
      ..place(EditorPiece.cornerSW, (col: 4, row: 1))
      ..place(EditorPiece.straightV, (col: 3, row: 2))
      ..place(EditorPiece.straightV, (col: 4, row: 2))
      ..place(EditorPiece.cornerNE, (col: 3, row: 3))
      ..place(EditorPiece.cornerNW, (col: 4, row: 3))
      ..place(EditorPiece.tramRed, (col: 4, row: 1));

    final buildResult = const EditorLevelBuilder().build(grid);
    expect(buildResult.isValid, isTrue);

    final game = TramGame(initialLevel: buildResult.level);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump();

    expect(game.trams.length, 2);
    expect(game.effectiveVisibleSize, Vector2(1040, 680));
  });

  testWidgets('TramGame spawns delayed trams only once time passes', (
    tester,
  ) async {
    final level = _loopLevel(
      spawns: const [
        {'segment': 'seg_a', 'time': 0, 'speed': 60, 'startDistance': 0},
        {'segment': 'seg_a', 'time': 1.5, 'speed': 60, 'startDistance': 300},
      ],
    );
    final game = TramGame(initialLevel: level);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump();

    expect(game.trams.length, 1);
    game.update(1.0);
    expect(game.trams.length, 1);
    game.update(0.6);
    expect(game.trams.length, 2);
  });

  testWidgets('TramGame detects head-on crash and triggers goalMetNotifier', (
    tester,
  ) async {
    final level = _loopLevel(
      spawns: const [
        {
          'segment': 'seg_a',
          'time': 0,
          'speed': 120,
          'startDistance': 150,
          'controls': 'wasd',
        },
        {
          'segment': 'seg_a',
          'time': 0,
          'speed': -120,
          'startDistance': 210,
          'controls': 'arrows',
        },
      ],
    );
    final game = TramGame(initialLevel: level);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump();

    expect(game.goalMetNotifier.value, isFalse);
    for (var i = 0; i < 20 && !game.goalMetNotifier.value; i++) {
      game.update(0.05);
    }

    expect(game.trams[0].isCrashed, isTrue);
    expect(game.trams[1].isCrashed, isTrue);
    expect(game.scoreSystem.crashCount, 1);
    expect(game.scoreSystem.isGoalMet, isTrue);
    expect(game.goalMetNotifier.value, isTrue);
  });

  testWidgets('TramGame detects open-segment TrackEnd hazard crash', (
    tester,
  ) async {
    final level = _loopLevel(
      end: 'river',
      points: const [
        [-100, 0],
        [100, 0],
      ],
      spawns: const [
        {'segment': 'seg_a', 'time': 0, 'speed': 150, 'startDistance': 185},
      ],
    );
    final game = TramGame(initialLevel: level);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump();

    expect(game.scoreSystem.crashCount, 0);
    game.update(0.2);

    expect(game.trams.single.isCrashed, isTrue);
    expect(game.scoreSystem.crashCount, 1);
    expect(game.goalMetNotifier.value, isTrue);
  });

  testWidgets('effectiveVisibleSize expands for levels larger than 1040x680', (
    tester,
  ) async {
    final game = TramGame(initialLevel: _loopLevel(width: 1400, height: 900));
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump();

    expect(game.effectiveVisibleSize, Vector2(1400, 900));
    expect(game.camera.viewfinder.visibleGameSize, Vector2(1400, 900));
  });

  testWidgets('RaceScreen shows victory banner once level goal is met', (
    tester,
  ) async {
    final level = _loopLevel(
      end: 'river',
      points: const [
        [-100, 0],
        [100, 0],
      ],
      spawns: const [
        {'segment': 'seg_a', 'time': 0, 'speed': 160, 'startDistance': 190},
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RaceScreen(level: level, onBackToEditor: () {}),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Cél teljesítve!'), findsNothing);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Cél teljesítve! (1/1 ütközés)'), findsOneWidget);
  });

  testWidgets('TramGame blocks second tram from boarding occupied turntable', (
    tester,
  ) async {
    final level = LevelData.fromJson({
      'id': 'lock_test',
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
        {
          'segment': 'ns',
          'time': 0,
          'speed': 120,
          'startDistance': 140,
          'controls': 'wasd',
        },
        {
          'segment': 'ew',
          'time': 0,
          'speed': 120,
          'startDistance': 140,
          'controls': 'arrows',
        },
      ],
      'goal': {'crashes': 1},
      'crossovers': [
        {
          'id': 'sw_center',
          'platformShape': 'circle',
          'x': 0,
          'y': 0,
          'links': [
            {'from': 'ns', 'to': 'ew'},
            {'from': 'ew', 'to': 'ns'},
          ],
        },
      ],
    });
    final game = TramGame(initialLevel: level);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump();

    expect(game.trams[0].requestTurn(), isTrue);
    expect(game.trams[0].ride, isNotNull);
    expect(game.trams[1].requestTurn(), isFalse);
    expect(game.trams[1].ride, isNull);
  });
}
