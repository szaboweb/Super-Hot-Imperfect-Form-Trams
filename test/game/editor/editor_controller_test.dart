import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_controller.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_grid.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_piece.dart';

void main() {
  group('EditorController', () {
    test('place, move, remove, and clear update grid and notify', () {
      final controller = EditorController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(
        controller.placePiece(EditorPiece.straightH, (col: 1, row: 1)),
        EditorEditResult.placed,
      );
      expect(controller.grid.railAt((col: 1, row: 1)), EditorPiece.straightH);

      expect(
        controller.movePiece((col: 1, row: 1), (col: 2, row: 1)),
        EditorEditResult.placed,
      );
      expect(controller.grid.railAt((col: 1, row: 1)), isNull);
      expect(controller.grid.railAt((col: 2, row: 1)), EditorPiece.straightH);

      expect(controller.removeAt((col: 2, row: 1)), EditorEditResult.placed);
      expect(controller.grid.isEmpty, isTrue);

      controller.placePiece(EditorPiece.straightV, (col: 0, row: 0));
      controller.clear();
      expect(controller.grid.isEmpty, isTrue);
      expect(notifications, greaterThanOrEqualTo(4));
    });

    test('placing tram on empty cell sets statusMessage', () {
      final controller = EditorController();
      final result = controller.placePiece(EditorPiece.tramGreen, (
        col: 0,
        row: 0,
      ));
      expect(result, EditorEditResult.needsPlainRail);
      expect(controller.statusMessage, isNotNull);
    });

    test('selectPiece and toggleEraseMode are mutually exclusive', () {
      final controller = EditorController();
      controller.selectPiece(EditorPiece.straightH);
      expect(controller.selectedPiece, EditorPiece.straightH);
      expect(controller.eraseMode, isFalse);

      expect(
        controller.handleCellTap((col: 3, row: 3)),
        EditorEditResult.placed,
      );
      expect(controller.grid.railAt((col: 3, row: 3)), EditorPiece.straightH);

      controller.toggleEraseMode();
      expect(controller.eraseMode, isTrue);
      expect(controller.selectedPiece, isNull);

      expect(
        controller.handleCellTap((col: 3, row: 3)),
        EditorEditResult.placed,
      );
      expect(controller.grid.railAt((col: 3, row: 3)), isNull);
    });

    test('buildLevel reports errors and errorCells for open ends', () {
      final controller = EditorController();
      controller.placePiece(EditorPiece.straightH, (col: 2, row: 3));
      controller.placePiece(EditorPiece.tramGreen, (col: 2, row: 3));
      // Add a second loop with red tram so only openEnd fails
      controller.placePiece(EditorPiece.cornerNW, (col: 5, row: 5));
      controller.placePiece(EditorPiece.cornerNE, (col: 6, row: 5));
      controller.placePiece(EditorPiece.cornerSW, (col: 5, row: 6));
      controller.placePiece(EditorPiece.cornerSE, (col: 6, row: 6));
      controller.placePiece(EditorPiece.tramRed, (col: 5, row: 5));

      final res = controller.buildLevel();
      expect(res.isValid, isFalse);
      expect(controller.errors, isNotEmpty);
      expect(controller.errorCells, contains((col: 2, row: 3)));
    });

    test('buildLevel succeeds on valid two-loop layout and clears errors', () {
      final controller = EditorController();
      // Loop 1: 2x2 at (1,1)-(2,2)
      controller.placePiece(EditorPiece.cornerSE, (col: 1, row: 1));
      controller.placePiece(EditorPiece.cornerSW, (col: 2, row: 1));
      controller.placePiece(EditorPiece.cornerNE, (col: 1, row: 2));
      controller.placePiece(EditorPiece.cornerNW, (col: 2, row: 2));
      controller.placePiece(EditorPiece.tramGreen, (col: 1, row: 1));

      // Loop 2: 2x2 at (4,1)-(5,2)
      controller.placePiece(EditorPiece.cornerSE, (col: 4, row: 1));
      controller.placePiece(EditorPiece.cornerSW, (col: 5, row: 1));
      controller.placePiece(EditorPiece.cornerNE, (col: 4, row: 2));
      controller.placePiece(EditorPiece.cornerNW, (col: 5, row: 2));
      controller.placePiece(EditorPiece.tramRed, (col: 4, row: 1));

      final res = controller.buildLevel();
      expect(res.isValid, isTrue);
      expect(res.level.spawns.length, 2);
      expect(controller.errors, isEmpty);
      expect(controller.errorCells, isEmpty);
    });
  });
}
