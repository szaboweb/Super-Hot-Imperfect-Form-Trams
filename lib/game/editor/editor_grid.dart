import 'dart:math' as math;

import 'editor_piece.dart';

/// Grid coordinate (column, row), origin at the top-left cell.
typedef EditorCell = ({int col, int row});

/// Outcome of a grid edit; anything but [placed] leaves the grid unchanged.
enum EditorEditResult {
  placed,
  outOfBounds,
  occupied,
  needsPlainRail,
  blockedByTram,
  nothingThere,
}

/// The editor's layout: one rail piece per cell plus at most one tram marker of
/// each colour (on a plain rail cell). Pure Dart, JSON-serialisable.
class EditorGrid {
  EditorGrid({this.cols = 16, this.rows = 10, this.tileSize = 64})
    : assert(cols > 0 && rows > 0 && tileSize > 0);

  factory EditorGrid.fromJson(Map<String, dynamic> json) {
    final grid = EditorGrid(
      cols: json['cols'] as int? ?? 16,
      rows: json['rows'] as int? ?? 10,
      tileSize: json['tileSize'] as int? ?? 64,
    );
    for (final r in (json['rails'] as List? ?? const [])) {
      final map = r as Map<String, dynamic>;
      final piece = _pieceByName(map['piece']);
      final result = grid.place(piece, (
        col: map['col'] as int,
        row: map['row'] as int,
      ));
      if (result != EditorEditResult.placed) {
        throw FormatException('Bad rail $map: ${result.name}');
      }
    }
    final trams = json['trams'] as Map<String, dynamic>? ?? const {};
    for (final entry in trams.entries) {
      final cell = entry.value as Map<String, dynamic>;
      final result = grid.place(_pieceByName(entry.key), (
        col: cell['col'] as int,
        row: cell['row'] as int,
      ));
      if (result != EditorEditResult.placed) {
        throw FormatException('Bad tram ${entry.key}: ${result.name}');
      }
    }
    return grid;
  }

  final int cols;
  final int rows;

  /// Cell edge length in world px (the level tileSize).
  final int tileSize;

  final Map<EditorCell, EditorPiece> _rails = {};
  final Map<EditorPiece, EditorCell> _trams = {};

  Map<EditorCell, EditorPiece> get rails => Map.unmodifiable(_rails);
  Map<EditorPiece, EditorCell> get trams => Map.unmodifiable(_trams);

  bool get isEmpty => _rails.isEmpty && _trams.isEmpty;

  /// Level playable area (world px, centred on the origin).
  double get worldWidth => (cols * tileSize).toDouble();
  double get worldHeight => (rows * tileSize).toDouble();

  bool inBounds(EditorCell c) =>
      c.col >= 0 && c.col < cols && c.row >= 0 && c.row < rows;

  EditorPiece? railAt(EditorCell c) => _rails[c];

  /// True when [cell] holds an auto-straight piece oriented vertically.
  bool isVerticalInline(EditorCell cell) {
    if (railAt(cell)?.isAutoStraight != true) return false;
    final west = _isSideOpen(cell, EditorSide.west);
    final east = _isSideOpen(cell, EditorSide.east);
    if (west && east) return false;
    final north = _isSideOpen(cell, EditorSide.north);
    final south = _isSideOpen(cell, EditorSide.south);
    if (north && south) return true;
    return (north || south) && !(west || east);
  }

  /// True when [cell] holds a [EditorPiece.switchRectangle] oriented
  /// vertically (north/south neighbours open, without both west/east open).
  bool isVerticalRectangle(EditorCell cell) =>
      railAt(cell) == EditorPiece.switchRectangle && isVerticalInline(cell);

  /// Side from which a rail connects into the buffer stop at [cell], or null
  /// if [cell] does not hold a buffer stop.
  EditorSide? bufferEntrySide(EditorCell cell) {
    if (railAt(cell) != EditorPiece.bufferStop) return null;
    for (final s in EditorSide.values) {
      final n = (col: cell.col + s.dCol, row: cell.row + s.dRow);
      final piece = railAt(n);
      if (piece == null) continue;
      if (piece.connectsToSide(
        s.opposite,
        verticalInline: isVerticalInline(n),
      )) {
        return s;
      }
    }
    return EditorSide.west;
  }

  /// Stem side of a directional T-switch at [cell], or null for other pieces.
  EditorSide? wyeStemSide(EditorCell cell) => railAt(cell)?.tStemSide;

  bool _isSideOpen(EditorCell cell, EditorSide side) {
    final n = (col: cell.col + side.dCol, row: cell.row + side.dRow);
    final piece = railAt(n);
    if (piece == null) return false;
    if (piece == EditorPiece.bufferStop) {
      return _bufferAcceptsFrom(n, side.opposite);
    }
    if (piece.isAutoStraight) return true;
    return piece.connectsToSide(side.opposite);
  }

  bool _bufferAcceptsFrom(EditorCell bufferCell, EditorSide fromSide) {
    for (final other in EditorSide.values) {
      if (other == fromSide) continue;
      final nb = (
        col: bufferCell.col + other.dCol,
        row: bufferCell.row + other.dRow,
      );
      final piece = railAt(nb);
      if (piece == null || piece == EditorPiece.bufferStop) continue;
      if (piece.isAutoStraight || piece.connectsToSide(other.opposite)) {
        return false;
      }
    }
    return true;
  }

  EditorPiece? tramAt(EditorCell c) {
    for (final e in _trams.entries) {
      if (e.value == c) return e.key;
    }
    return null;
  }

  EditorCell? tramCell(EditorPiece tram) => _trams[tram];

  /// World position (px) of the centre of [c]; the grid is centred on the origin.
  math.Point<double> cellCenter(EditorCell c) => math.Point(
    (c.col - cols / 2 + 0.5) * tileSize,
    (c.row - rows / 2 + 0.5) * tileSize,
  );

  /// Cell under world point [p], or null outside the grid.
  EditorCell? cellAt(math.Point<double> p) {
    final cell = (
      col: ((p.x / tileSize) + cols / 2).floor(),
      row: ((p.y / tileSize) + rows / 2).floor(),
    );
    return inBounds(cell) ? cell : null;
  }

  /// Puts [piece] on [cell]. A rail replaces the rail already there; a tram
  /// marker moves if that colour is already on the grid.
  EditorEditResult place(EditorPiece piece, EditorCell cell) {
    if (!inBounds(cell)) return EditorEditResult.outOfBounds;
    if (piece.isTram) return _placeTram(piece, cell);
    if (piece.blocksTram && tramAt(cell) != null) {
      return EditorEditResult.blockedByTram;
    }
    _rails[cell] = piece;
    return EditorEditResult.placed;
  }

  EditorEditResult _placeTram(EditorPiece tram, EditorCell cell) {
    if (_rails[cell]?.isPlainRail != true) {
      return EditorEditResult.needsPlainRail;
    }
    final other = tramAt(cell);
    if (other != null && other != tram) return EditorEditResult.occupied;
    _trams[tram] = cell;
    return EditorEditResult.placed;
  }

  /// Removes the top item of [cell]: the tram marker if there is one, else the
  /// rail (so removing a rail that carries a tram takes two calls).
  EditorEditResult remove(EditorCell cell) {
    final tram = tramAt(cell);
    if (tram != null) {
      _trams.remove(tram);
      return EditorEditResult.placed;
    }
    if (_rails.remove(cell) == null) return EditorEditResult.nothingThere;
    return EditorEditResult.placed;
  }

  /// Moves the top item of [from] to [to]: the tram marker if there is one (it
  /// needs a plain rail at [to]), else the bare rail (needs an empty target).
  EditorEditResult move(EditorCell from, EditorCell to) {
    if (!inBounds(to)) return EditorEditResult.outOfBounds;
    final tram = tramAt(from);
    if (tram != null) return _placeTram(tram, to);
    final rail = _rails[from];
    if (rail == null) return EditorEditResult.nothingThere;
    if (from == to) return EditorEditResult.placed;
    if (_rails.containsKey(to)) return EditorEditResult.occupied;
    _rails
      ..remove(from)
      ..[to] = rail;
    return EditorEditResult.placed;
  }

  void clear() {
    _rails.clear();
    _trams.clear();
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'cols': cols,
    'rows': rows,
    'tileSize': tileSize,
    'rails': [
      for (final e in _rails.entries)
        {'col': e.key.col, 'row': e.key.row, 'piece': e.value.name},
    ],
    'trams': {
      for (final e in _trams.entries)
        e.key.name: {'col': e.value.col, 'row': e.value.row},
    },
  };

  static EditorPiece _pieceByName(Object? name) {
    if (name == 'switchY') return EditorPiece.switchTSouth;
    return EditorPiece.values.asNameMap()[name] ??
        (throw FormatException('Unknown editor piece "$name"'));
  }

  /// Lossless compact ASCII map of rails plus 1-based tram coordinates.
  String toAscii() {
    final lines = [
      for (var row = 0; row < rows; row++)
        [
          for (var col = 0; col < cols; col++)
            _asciiChar(railAt((col: col, row: row))),
        ].join(),
      'G:${_tramCoord(EditorPiece.tramGreen)} R:${_tramCoord(EditorPiece.tramRed)}',
    ];
    return lines.join('\n');
  }

  String _tramCoord(EditorPiece tram) {
    final c = _trams[tram];
    return c == null ? '-' : '${c.col + 1},${c.row + 1}';
  }

  static String _asciiChar(EditorPiece? piece) => switch (piece) {
    EditorPiece.straightH => '─',
    EditorPiece.straightV => '│',
    EditorPiece.cornerSE => '┌',
    EditorPiece.cornerSW => '┐',
    EditorPiece.cornerNE => '└',
    EditorPiece.cornerNW => '┘',
    EditorPiece.crossing => '┼',
    EditorPiece.bufferStop => '▪',
    EditorPiece.switchCircle => '◎',
    EditorPiece.switchRectangle => '▬',
    EditorPiece.switchTriangle => '△',
    EditorPiece.switchTNorth ||
    EditorPiece.switchTSouth ||
    EditorPiece.switchTEast ||
    EditorPiece.switchTWest => 'T',
    EditorPiece.switchYNorthLeft ||
    EditorPiece.switchYNorthRight ||
    EditorPiece.switchYSouthLeft ||
    EditorPiece.switchYSouthRight ||
    EditorPiece.switchYEastLeft ||
    EditorPiece.switchYEastRight ||
    EditorPiece.switchYWestLeft ||
    EditorPiece.switchYWestRight => 'Y',
    EditorPiece.gate => '╫',
    EditorPiece.railIce => '≈',
    EditorPiece.railMelted => '~',
    EditorPiece.tramGreen || EditorPiece.tramRed || null => '.',
  };
}
