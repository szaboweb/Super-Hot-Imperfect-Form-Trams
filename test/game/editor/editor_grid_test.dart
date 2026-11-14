import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_grid.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_piece.dart';

import 'editor_sample_layouts.dart';

void main() {
  const a = (col: 1, row: 1);
  const b = (col: 2, row: 1);

  test('place, replace and bounds', () {
    final g = EditorGrid();
    expect(g.place(EditorPiece.straightH, a), EditorEditResult.placed);
    expect(g.place(EditorPiece.straightV, a), EditorEditResult.placed);
    expect(g.railAt(a), EditorPiece.straightV);
    expect(g.rails.length, 1);
    expect(
      g.place(EditorPiece.straightH, (col: 16, row: 0)),
      EditorEditResult.outOfBounds,
    );
    expect(
      g.place(EditorPiece.straightH, (col: 0, row: -1)),
      EditorEditResult.outOfBounds,
    );
  });

  test('cell centres are centred on the origin', () {
    final g = EditorGrid();
    expect(g.cellCenter((col: 0, row: 0)).x, -480);
    expect(g.cellCenter((col: 15, row: 9)).y, 288);
    final c = g.cellCenter((col: 3, row: 4));
    expect(g.cellAt(c), (col: 3, row: 4));
    expect(g.worldWidth, 1024);
  });

  test('remove takes the tram first, then the rail', () {
    final g = EditorGrid()..place(EditorPiece.straightH, a);
    g.place(EditorPiece.tramGreen, a);
    expect(g.remove(a), EditorEditResult.placed);
    expect(g.tramCell(EditorPiece.tramGreen), isNull);
    expect(g.railAt(a), isNotNull);
    expect(g.remove(a), EditorEditResult.placed);
    expect(g.remove(a), EditorEditResult.nothingThere);
  });

  test('move: tram needs a plain rail, bare rail needs an empty cell', () {
    final g = EditorGrid()
      ..place(EditorPiece.straightH, a)
      ..place(EditorPiece.straightH, b)
      ..place(EditorPiece.straightV, (col: 5, row: 5));
    expect(g.move(b, a), EditorEditResult.occupied);
    expect(g.move(b, (col: 6, row: 6)), EditorEditResult.placed);
    expect(g.railAt((col: 6, row: 6)), EditorPiece.straightH);
    g.place(EditorPiece.tramRed, a);
    expect(g.move(a, (col: 5, row: 5)), EditorEditResult.placed);
    expect(g.tramCell(EditorPiece.tramRed), (col: 5, row: 5));
    expect(g.move(b, a), EditorEditResult.nothingThere);
    expect(g.move(a, (col: 99, row: 0)), EditorEditResult.outOfBounds);
  });

  test('tram rules: plain rail only, one per colour, one per cell', () {
    final g = EditorGrid();
    expect(g.place(EditorPiece.tramGreen, a), EditorEditResult.needsPlainRail);
    g
      ..place(EditorPiece.straightH, a)
      ..place(EditorPiece.straightH, b)
      ..place(EditorPiece.switchCircle, (col: 3, row: 1));
    expect(g.place(EditorPiece.tramGreen, a), EditorEditResult.placed);
    expect(g.place(EditorPiece.tramRed, a), EditorEditResult.occupied);
    expect(
      g.place(EditorPiece.tramGreen, (col: 3, row: 1)),
      EditorEditResult.needsPlainRail,
    );
    expect(g.place(EditorPiece.tramGreen, b), EditorEditResult.placed);
    expect(g.trams.length, 1);
    expect(g.tramCell(EditorPiece.tramGreen), b);
    expect(
      g.place(EditorPiece.switchTriangle, b),
      EditorEditResult.blockedByTram,
    );
  });

  test('JSON round trip keeps rails and trams', () {
    final g = crossingRings();
    final copy = EditorGrid.fromJson(g.toJson());
    expect(copy.toJson(), g.toJson());
    expect(copy.rails.length, g.rails.length);
    expect(copy.tramCell(EditorPiece.tramRed), (col: 9, row: 8));
    expect(
      () => EditorGrid.fromJson({
        'rails': [
          {'col': 99, 'row': 0, 'piece': 'straightH'},
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => EditorGrid.fromJson({
        'rails': [
          {'col': 0, 'row': 0, 'piece': 'x'},
        ],
      }),
      throwsFormatException,
    );
  });

  test('clear empties the grid', () {
    final g = crossingRings()..clear();
    expect(g.isEmpty, isTrue);
  });
}
