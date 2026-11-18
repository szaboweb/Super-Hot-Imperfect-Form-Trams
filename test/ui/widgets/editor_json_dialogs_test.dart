import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/core/json_file_service.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_controller.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_piece.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_data.dart';
import 'package:super_hot_imperfect_form_trams/ui/widgets/editor_json_dialogs.dart';

EditorController _validTwoLoopController() {
  final c = EditorController();
  for (final e in const [
    (EditorPiece.cornerSE, (col: 1, row: 1)),
    (EditorPiece.cornerSW, (col: 2, row: 1)),
    (EditorPiece.straightV, (col: 1, row: 2)),
    (EditorPiece.straightV, (col: 2, row: 2)),
    (EditorPiece.switchRectangle, (col: 2, row: 2)),
    (EditorPiece.cornerNE, (col: 1, row: 3)),
    (EditorPiece.cornerNW, (col: 2, row: 3)),
    (EditorPiece.tramGreen, (col: 1, row: 1)),
    (EditorPiece.cornerSE, (col: 3, row: 1)),
    (EditorPiece.cornerSW, (col: 4, row: 1)),
    (EditorPiece.straightV, (col: 3, row: 2)),
    (EditorPiece.straightV, (col: 4, row: 2)),
    (EditorPiece.cornerNE, (col: 3, row: 3)),
    (EditorPiece.cornerNW, (col: 4, row: 3)),
    (EditorPiece.tramRed, (col: 4, row: 1)),
  ]) {
    c.placePiece(e.$1, e.$2);
  }
  return c;
}

void main() {
  testWidgets('export dialog saves grid and playable JSON to file', (
    tester,
  ) async {
    final controller = _validTwoLoopController();
    final saved = <({String name, String contents})>[];
    final fileService = JsonFileService(
      onSave: (name, contents) async {
        saved.add((name: name, contents: contents));
        return name;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showEditorExportDialog(
                  context,
                  controller,
                  fileService: fileService,
                ),
                child: const Text('EXPORT'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('EXPORT'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Játszható pálya (.json)'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'teszt_palya');
    await tester.tap(find.text('Mentés fájlba (.json)'));
    await tester.pumpAndSettle();

    expect(saved.length, 1);
    expect(saved.single.name, 'teszt_palya.json');
    final decoded = jsonDecode(saved.single.contents) as Map<String, dynamic>;
    expect(LevelData.fromJson(decoded).segments, isNotEmpty);
    expect(controller.statusMessage, contains('teszt_palya.json'));
  });

  testWidgets('import dialog loads .json file and rejects malformed JSON', (
    tester,
  ) async {
    final source = _validTwoLoopController();
    final target = EditorController();
    var pickCount = 0;
    final fileService = JsonFileService(
      onPick: () async {
        pickCount++;
        if (pickCount == 1) {
          return (name: 'hibas.json', contents: '{nem json');
        }
        return (name: 'jo_palya.json', contents: source.exportJson());
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showEditorImportDialog(
                  context,
                  target,
                  fileService: fileService,
                ),
                child: const Text('IMPORT'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('IMPORT'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fájl kiválasztása (.json)...'));
    await tester.pump();
    expect(find.textContaining('nem érvényes'), findsOneWidget);

    await tester.tap(find.text('Fájl kiválasztása (.json)...'));
    await tester.pumpAndSettle();

    expect(target.grid.rails.length, source.grid.rails.length);
    expect(target.statusMessage, contains('jo_palya.json'));
  });
}
