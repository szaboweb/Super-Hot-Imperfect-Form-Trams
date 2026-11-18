import 'editor_grid.dart';
import 'editor_piece.dart';

/// A structured validation issue with an optional grid [cell] to highlight.
class EditorIssue {
  const EditorIssue(this.message, {this.cell});

  final String message;
  final EditorCell? cell;
}

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

  static String rectOpposite(EditorCell c) =>
      'Téglalap kitérő ${_at(c)}: a két sáv ellentétes irányú, nem forgatható egyeztetni.';

  static String rectDuplicate(EditorCell c) =>
      'Téglalap kitérő ${_at(c)}: ezen a sávpáron már van egy téglalap kitérő.';

  static String switchOverlap(EditorCell c) =>
      'Átfedő váltók ${_at(c)}: két váltó túl közel van egymáshoz (min. 96 px).';

  static String disconnectedTrack(EditorCell c) =>
      'Különálló pályarész ${_at(c)}: erről a sínről nem lehet átváltani.';

  /// Error message when a buffer stop does not connect to exactly one rail.
  static String bufferConnections(EditorCell c) =>
      'Ütközőbak ${_at(c)}: pontosan egy sínvéghez csatlakozhat.';

  /// Error message when a Y-switch has fewer than three connected rail arms.
  static String wyeConnections(EditorCell c) =>
      'Y váltó ${_at(c)}: legalább három csatlakozó sínág szükséges.';

  static String levelInvalid(String detail) => 'Érvénytelen pálya: $detail';
}
