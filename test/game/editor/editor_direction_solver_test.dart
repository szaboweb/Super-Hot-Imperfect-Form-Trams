import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_direction_solver.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_grid.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_messages.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_piece.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_tracer.dart';

void main() {
  ({int ring, EditorPass pass}) laneEntry(int ring, EditorCell cell) =>
      (ring: ring, pass: EditorPass(cell, EditorSide.west, EditorSide.east));

  void expectSatisfied(
    List<EditorRingConstraint> constraints,
    Set<int> reversed,
  ) {
    for (final c in constraints) {
      final aRev = reversed.contains(c.a);
      final bRev = reversed.contains(c.b);
      expect(aRev != bRev, c.differ, reason: 'constraint $c');
    }
  }

  group('EditorDirectionSolver.solve', () {
    test('returns empty result for empty constraints', () {
      final solver = EditorDirectionSolver(EditorGrid(), const {});
      final result = solver.solve(const []);
      expect(result.reversedRings, isEmpty);
      expect(result.issues, isEmpty);
    });

    test('keeps same-direction rings unreversed', () {
      final solver = EditorDirectionSolver(EditorGrid(), const {});
      final constraints = [
        (a: 0, b: 1, differ: false),
        (a: 1, b: 2, differ: false),
      ];
      final result = solver.solve(constraints);
      expect(result.issues, isEmpty);
      expect(result.reversedRings, isEmpty);
      expectSatisfied(constraints, result.reversedRings);
    });

    test('flips opposite-ring parity across chained constraints', () {
      final solver = EditorDirectionSolver(EditorGrid(), const {});
      final constraints = [
        (a: 0, b: 1, differ: true),
        (a: 1, b: 2, differ: true),
        (a: 2, b: 3, differ: false),
        (a: 3, b: 4, differ: true),
      ];
      final result = solver.solve(constraints);
      expect(result.issues, isEmpty);
      expect(result.reversedRings, {1, 4});
      expectSatisfied(constraints, result.reversedRings);
    });

    test('solves consistent even-parity cycles and disjoint components', () {
      final solver = EditorDirectionSolver(EditorGrid(), const {});
      final constraints = [
        (a: 0, b: 1, differ: true),
        (a: 1, b: 2, differ: true),
        (a: 2, b: 0, differ: false),
        (a: 4, b: 5, differ: true),
        (a: 5, b: 6, differ: false),
      ];
      final result = solver.solve(constraints);
      expect(result.issues, isEmpty);
      expect(result.reversedRings, {1, 5, 6});
      expectSatisfied(constraints, result.reversedRings);
    });

    test('detects odd-parity cycle conflicts and reports once per pair', () {
      final grid = EditorGrid();
      const swCell = (col: 4, row: 3);
      grid.place(EditorPiece.straightH, (col: 3, row: 3));
      grid.place(EditorPiece.switchRectangle, swCell);
      grid.place(EditorPiece.straightH, (col: 5, row: 3));
      final solver = EditorDirectionSolver(grid, {
        (swCell, true): laneEntry(1, swCell),
      });
      final constraints = [
        (a: 0, b: 1, differ: true),
        (a: 1, b: 2, differ: false),
        (a: 0, b: 2, differ: false),
        (a: 2, b: 1, differ: false),
      ];
      final result = solver.solve(constraints);
      expect(result.issues, hasLength(1));
      expect(result.issues.single.cell, swCell);
      expect(result.issues.single.message, EditorMessages.rectOpposite(swCell));
    });

    test('detects contradictory direct edges and self-opposite edge', () {
      final solver = EditorDirectionSolver(EditorGrid(), const {});
      final direct = solver.solve([
        (a: 0, b: 1, differ: false),
        (a: 0, b: 1, differ: true),
      ]);
      expect(direct.issues, hasLength(1));
      expect(direct.issues.single.cell, (col: 0, row: 0));

      final selfLoop = solver.solve([(a: 3, b: 3, differ: true)]);
      expect(selfLoop.issues, hasLength(1));
      expect(selfLoop.issues.single.cell, (col: 0, row: 0));
    });
  });

  group('EditorDirectionSolver.cellOfRings', () {
    test('reports rectangle or Y-switch cell linked to either ring', () {
      final grid = EditorGrid();
      const plainCell = (col: 2, row: 2);
      const rectCell = (col: 6, row: 4);
      const yCell = (col: 9, row: 5);
      grid.place(EditorPiece.straightH, plainCell);
      grid.place(EditorPiece.switchRectangle, rectCell);
      grid.place(EditorPiece.switchYNorthRight, yCell);

      final solver = EditorDirectionSolver(grid, {
        (plainCell, true): laneEntry(0, plainCell),
        (rectCell, true): laneEntry(0, rectCell),
        (yCell, false): laneEntry(2, yCell),
      });

      expect(solver.cellOfRings(0, 1), rectCell);
      expect(solver.cellOfRings(5, 2), yCell);
      expect(solver.cellOfRings(7, 8), (col: 0, row: 0));
    });
  });
}
