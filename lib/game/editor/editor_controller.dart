import 'package:flutter/foundation.dart';

import 'editor_grid.dart';
import 'editor_level_builder.dart';
import 'editor_piece.dart';

/// State and edit/build actions for the track editor, kept separate from UI.
class EditorController extends ChangeNotifier {
  EditorController({
    EditorGrid? grid,
    this._builder = const EditorLevelBuilder(),
  }) : grid = grid ?? EditorGrid();

  static final RegExp _cellPattern = RegExp(r'\((\d+)\. oszlop, (\d+)\. sor\)');

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
    if (result.isValid) {
      _errors = const [];
      _errorCells = const {};
    } else {
      _errors = List.unmodifiable(result.errors);
      _errorCells = _extractErrorCells(result.errors);
    }
    _statusMessage = null;
    notifyListeners();
    return result;
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
    EditorEditResult.needsPlainRail =>
      'Villamost csak egyszerű sínre vagy téglalap kitérőre tehetsz.',
    EditorEditResult.blockedByTram =>
      'Előbb vedd le a villamost erről a celláról.',
    EditorEditResult.nothingThere => null,
  };

  Set<EditorCell> _extractErrorCells(List<String> messages) {
    final cells = <EditorCell>{};
    for (final msg in messages) {
      for (final match in _cellPattern.allMatches(msg)) {
        final col = int.parse(match.group(1)!) - 1;
        final row = int.parse(match.group(2)!) - 1;
        final cell = (col: col, row: row);
        if (grid.inBounds(cell)) cells.add(cell);
      }
    }
    return Set.unmodifiable(cells);
  }
}
