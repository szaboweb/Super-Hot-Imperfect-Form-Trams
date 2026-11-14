import 'editor_grid.dart';
import 'editor_piece.dart';

/// Every message the editor level builder can report (Hungarian), in one place.
abstract final class EditorMessages {
  static const String emptyGrid = 'Üres pálya: tegyél le sínt.';

  static String _at(EditorCell c) =>
      '(${c.col + 1}. oszlop, ${c.row + 1}. sor)';

  static String _side(EditorSide s) => switch (s) {
    EditorSide.north => 'felső',
    EditorSide.east => 'jobb',
    EditorSide.south => 'alsó',
    EditorSide.west => 'bal',
  };

  static String openEnd(EditorCell c, EditorSide s) =>
      'Nyitott sínvég ${_at(c)}: a ${_side(s)} oldalon nincs folytatás.';

  static String missingTram(EditorPiece tram) => tram == EditorPiece.tramGreen
      ? 'Hiányzik a zöld villamos (W/S + bal SHIFT).'
      : 'Hiányzik a piros villamos (nyilak + jobb SHIFT).';

  static String rectNoLane(EditorCell c) =>
      'Téglalap kitérő ${_at(c)}: a szomszéd cellában nincs párhuzamos egyenes sín.';

  static String rectSameLoop(EditorCell c) =>
      'Téglalap kitérő ${_at(c)}: a két sáv ugyanahhoz a körhöz tartozik.';

  static String rectOpposite(EditorCell c) =>
      'Téglalap kitérő ${_at(c)}: a két sáv ellentétes irányú, nem forgatható egyeztetni.';

  static String circleSameLoop(EditorCell c) =>
      'Kör váltó ${_at(c)}: mindkét sín ugyanahhoz a körhöz tartozik.';

  static String levelInvalid(String detail) => 'Érvénytelen pálya: $detail';
}
