import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/game_log.dart';
import 'editor_grid.dart';
import 'editor_level_builder.dart';
import 'editor_piece.dart';

/// State and edit/build actions for the track editor, kept separate from UI.
class EditorController extends ChangeNotifier {
  EditorController({
    EditorGrid? grid,
    this._builder = const EditorLevelBuilder(),
  }) : grid = grid ?? EditorGrid();

  final EditorGrid grid;
  final EditorLevelBuilder _builder;

  EditorPiece? _selectedPiece;
  bool _eraseMode = false;
  List<String> _errors = const [];
  Set<EditorCell> _errorCells = const {};
  String? _statusMessage;

  EditorPiece? get selectedPiece => _selectedPiece;
  bool get eraseMode => _eraseMode;
  List<String> get errors => _errors;
  Set<EditorCell> get errorCells => _errorCells;
  String? get statusMessage => _statusMessage;

  /// Selects a piece from the sidebar for click-to-place (turns off erase mode).
  void selectPiece(EditorPiece? piece) {
    _selectedPiece = piece;
    if (piece != null) _eraseMode = false;
    _statusMessage = null;
    notifyListeners();
  }

  /// Toggles click-to-erase mode (clears any selected piece).
  void toggleEraseMode() {
    _eraseMode = !_eraseMode;
    if (_eraseMode) _selectedPiece = null;
    _statusMessage = null;
    notifyListeners();
  }

  /// Places [piece] onto [cell] and records a status message if rejected.
  EditorEditResult placePiece(EditorPiece piece, EditorCell cell) {
    final result = grid.place(piece, cell);
    _afterEdit(result);
    return result;
  }

  /// Moves the top item of [from] to [to].
  EditorEditResult movePiece(EditorCell from, EditorCell to) {
    final result = grid.move(from, to);
    _afterEdit(result);
    return result;
  }

  /// Removes the top item (tram first, then rail) from [cell].
  EditorEditResult removeAt(EditorCell cell) {
    final result = grid.remove(cell);
    _errors = const [];
    _errorCells = const {};
    _statusMessage = null;
    notifyListeners();
    return result;
  }

  /// Applies the active tool (erase or selected piece) on a cell tap.
  EditorEditResult handleCellTap(EditorCell cell) {
    if (_eraseMode) return removeAt(cell);
    if (_selectedPiece != null) return placePiece(_selectedPiece!, cell);
    return EditorEditResult.nothingThere;
  }

  /// Empties the entire grid and clears any error/status banners.
  void clear() {
    grid.clear();
    _errors = const [];
    _errorCells = const {};
    _statusMessage = null;
    notifyListeners();
  }

  /// Validates and builds a playable [LevelData] from the current grid.
  EditorBuildResult buildLevel() {
    final result = _builder.build(grid);
    if (!grid.isEmpty) {
      GameLog.event('editor', 'Térkép:\n${grid.toAscii()}');
    }
    if (result.isValid) {
      _errors = const [];
      _errorCells = const {};
      GameLog.event(
        'editor',
        'Pálya érvényes (${grid.rails.length} sín elem).',
      );
    } else {
      _errors = List.unmodifiable(result.errors);
      _errorCells = Set.unmodifiable({
        for (final issue in result.issues)
          if (issue.cell != null) issue.cell!,
      });
      for (final error in result.errors) {
        GameLog.event('editor', error);
      }
    }
    _statusMessage = null;
    notifyListeners();
    return result;
  }

  /// Exports the current [grid] layout as formatted JSON.
  String exportJson() =>
      const JsonEncoder.withIndent('  ').convert(grid.toJson());

  /// Exports the validated playable [LevelData] JSON string, or null if layout has errors.
  String? exportPlayableLevelJson() {
    final result = _builder.build(grid);
    final json = result.json;
    if (json == null) return null;
    return const JsonEncoder.withIndent('  ').convert(json);
  }

  /// Sets an informational status message on the editor banner.
  void showStatus(String message) {
    _statusMessage = message;
    notifyListeners();
  }

  /// Imports a JSON layout string into [grid], returning whether it succeeded.
  bool importJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('A JSON gyökér nem objektum.');
      }
      final loaded = EditorGrid.fromJson(decoded);
      grid.clear();
      for (final e in loaded.rails.entries) {
        grid.place(e.value, e.key);
      }
      for (final e in loaded.trams.entries) {
        grid.place(e.key, e.value);
      }
      _errors = const [];
      _errorCells = const {};
      _statusMessage = 'Pálya betöltve (${grid.rails.length} sín elem).';
      notifyListeners();
      return true;
    } on FormatException {
      _statusMessage = 'Érvénytelen JSON vagy pályaadat.';
      notifyListeners();
      return false;
    } on TypeError {
      _statusMessage = 'Érvénytelen JSON szerkezet.';
      notifyListeners();
      return false;
    }
  }

  void _afterEdit(EditorEditResult result) {
    _errors = const [];
    _errorCells = const {};
    _statusMessage = _messageForResult(result);
    notifyListeners();
  }

  String? _messageForResult(EditorEditResult result) => switch (result) {
    EditorEditResult.placed => null,
    EditorEditResult.outOfBounds => 'A cella a pályán kívül esik.',
    EditorEditResult.occupied => 'A célcella már foglalt.',
    EditorEditResult.needsPlainRail => 'Villamost csak nyílt sínre (egyenes, kanyar, téglalap kitérő, jeges/olvadt sín) tehetsz.',
    EditorEditResult.blockedByTram =>
      'Előbb vedd le a villamost erről a celláról.',
    EditorEditResult.nothingThere => null,
  };
}
