import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_grid.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_level_builder.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_piece.dart';
import 'package:super_hot_imperfect_form_trams/game/tram_game.dart';

void main() {
  testWidgets('TramGame loads a runtime LevelData directly', (tester) async {
    final grid = EditorGrid()
      ..place(EditorPiece.cornerSE, (col: 1, row: 1))
      ..place(EditorPiece.cornerSW, (col: 2, row: 1))
      ..place(EditorPiece.cornerNE, (col: 1, row: 2))
      ..place(EditorPiece.cornerNW, (col: 2, row: 2))
      ..place(EditorPiece.tramGreen, (col: 1, row: 1))
      ..place(EditorPiece.cornerSE, (col: 4, row: 1))
      ..place(EditorPiece.cornerSW, (col: 5, row: 1))
      ..place(EditorPiece.cornerNE, (col: 4, row: 2))
      ..place(EditorPiece.cornerNW, (col: 5, row: 2))
      ..place(EditorPiece.tramRed, (col: 4, row: 1));

    final buildResult = const EditorLevelBuilder().build(grid);
    expect(buildResult.isValid, isTrue);

    final game = TramGame(initialLevel: buildResult.level);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump();

    expect(game.trams.length, 2);
  });
}
