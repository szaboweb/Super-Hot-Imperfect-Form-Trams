import 'package:super_hot_imperfect_form_trams/game/editor/editor_grid.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_piece.dart';

/// Draws a rectangular ring of rails with corners (c0,r0)..(c1,r1).
void drawRing(EditorGrid g, int c0, int r0, int c1, int r1) {
  void put(EditorPiece p, int col, int row) => g.place(p, (col: col, row: row));
  put(EditorPiece.cornerSE, c0, r0);
  put(EditorPiece.cornerSW, c1, r0);
  put(EditorPiece.cornerNE, c0, r1);
  put(EditorPiece.cornerNW, c1, r1);
  for (var c = c0 + 1; c < c1; c++) {
    put(EditorPiece.straightH, c, r0);
    put(EditorPiece.straightH, c, r1);
  }
  for (var r = r0 + 1; r < r1; r++) {
    put(EditorPiece.straightV, c0, r);
    put(EditorPiece.straightV, c1, r);
  }
}

/// Two rings that cross at (8,4) and (6,6): circle and triangle switch,
/// green tram on the first ring, red tram on the second (like example_two_loops).
EditorGrid crossingRings() {
  final g = EditorGrid();
  drawRing(g, 2, 2, 8, 6);
  drawRing(g, 6, 4, 12, 8);
  g.place(EditorPiece.switchCircle, (col: 8, row: 4));
  g.place(EditorPiece.switchTriangle, (col: 6, row: 6));
  g.place(EditorPiece.tramGreen, (col: 4, row: 2));
  g.place(EditorPiece.tramRed, (col: 9, row: 8));
  return g;
}

/// Two stacked rings sharing the lane gap at rows 3/4; rectangle switch on
/// the top ring's bottom lane (5,3) slides to the lower ring's top lane (5,4).
EditorGrid stackedRings() {
  final g = EditorGrid();
  drawRing(g, 2, 1, 8, 3);
  drawRing(g, 2, 4, 8, 6);
  g.place(EditorPiece.switchRectangle, (col: 5, row: 3));
  g.place(EditorPiece.tramGreen, (col: 4, row: 1));
  g.place(EditorPiece.tramRed, (col: 4, row: 6));
  return g;
}
