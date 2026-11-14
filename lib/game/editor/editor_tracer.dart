import 'editor_grid.dart';
import 'editor_piece.dart';

/// One straight or corner run through a cell, oriented from [from] to [to].
class EditorPass {
  const EditorPass(this.cell, this.from, this.to);

  final EditorCell cell;
  final EditorSide from;
  final EditorSide to;

  bool get isStraight => from.opposite == to;

  /// True for a left-right pass (straight only).
  bool get isHorizontal => isStraight && from.isHorizontal;

  EditorPass get reversed => EditorPass(cell, to, from);
}

/// A closed ring of passes (one level segment).
class EditorRing {
  const EditorRing(this.passes);

  final List<EditorPass> passes;

  EditorRing get reversed =>
      EditorRing([for (final p in passes.reversed) p.reversed]);
}

/// Pairs of connected sides per cell: what rails do in each cell (no direction).
typedef EditorSidePair = ({EditorSide a, EditorSide b});

/// Reads an [EditorGrid] into connected rings and reports open ends.
class EditorTracer {
  EditorTracer(this.grid) {
    for (final e in grid.rails.entries) {
      _pairs[e.key] = _pairsOf(e.key, e.value);
    }
  }

  final EditorGrid grid;
  final Map<EditorCell, List<EditorSidePair>> _pairs = {};

  static const _startPriority = [
    EditorSide.east,
    EditorSide.south,
    EditorSide.west,
    EditorSide.north,
  ];

  /// Open ends: every side of every pair must meet a pair of the neighbour.
  List<({EditorCell cell, EditorSide side})> openEnds() => [
    for (final cell in _sortedCells())
      for (final pair in _pairs[cell]!)
        for (final side in [pair.a, pair.b])
          if (_pairAt(_neighbour(cell, side), side.opposite) == null)
            (cell: cell, side: side),
  ];

  /// Rings in row-major order of their first cell, each driven clockwise-ish
  /// (east/south first). Only call when [openEnds] is empty.
  List<EditorRing> rings() {
    final seen = <(EditorCell, int)>{};
    final rings = <EditorRing>[];
    for (final cell in _sortedCells()) {
      final pairs = _pairs[cell]!;
      for (var i = 0; i < pairs.length; i++) {
        if (seen.contains((cell, i))) continue;
        rings.add(_walk(cell, i, seen));
      }
    }
    return rings;
  }

  EditorRing _walk(EditorCell start, int index, Set<(EditorCell, int)> seen) {
    final pair = _pairs[start]![index];
    var exit = _startPriority.firstWhere((s) => s == pair.a || s == pair.b);
    var pass = EditorPass(start, exit == pair.a ? pair.b : pair.a, exit);
    final passes = <EditorPass>[];
    while (true) {
      seen.add((pass.cell, _indexOf(pass.cell, pass.from)));
      passes.add(pass);
      final next = _neighbour(pass.cell, pass.to);
      final entry = pass.to.opposite;
      final nextPair = _pairAt(next, entry)!;
      exit = nextPair.a == entry ? nextPair.b : nextPair.a;
      pass = EditorPass(next, entry, exit);
      if (pass.cell == start && _indexOf(next, entry) == index) break;
    }
    return EditorRing(passes);
  }

  List<EditorCell> _sortedCells() {
    final cells = _pairs.keys.toList()
      ..sort((x, y) => x.row != y.row ? x.row - y.row : x.col - y.col);
    return cells;
  }

  EditorCell _neighbour(EditorCell c, EditorSide s) =>
      (col: c.col + s.dCol, row: c.row + s.dRow);

  int _indexOf(EditorCell cell, EditorSide side) =>
      _pairs[cell]!.indexWhere((p) => p.a == side || p.b == side);

  EditorSidePair? _pairAt(EditorCell cell, EditorSide side) {
    final pairs = _pairs[cell];
    if (pairs == null) return null;
    for (final p in pairs) {
      if (p.a == side || p.b == side) return p;
    }
    return null;
  }

  List<EditorSidePair> _pairsOf(EditorCell cell, EditorPiece piece) {
    if (piece.isCrossing) {
      return [
        (a: EditorSide.west, b: EditorSide.east),
        (a: EditorSide.north, b: EditorSide.south),
      ];
    }
    if (piece == EditorPiece.switchRectangle) {
      return [_rectanglePair(cell)];
    }
    return [(a: piece.sides[0], b: piece.sides[1])];
  }

  /// A rectangle switch is a straight: horizontal if both left/right
  /// neighbours can connect to it, else vertical (horizontal as the fallback).
  EditorSidePair _rectanglePair(EditorCell cell) {
    bool open(EditorSide s) {
      final n = _neighbour(cell, s);
      final piece = grid.railAt(n);
      if (piece == null) return false;
      if (piece == EditorPiece.switchRectangle || piece.isCrossing) return true;
      return piece.sides.contains(s.opposite);
    }

    final vertical =
        !(open(EditorSide.west) && open(EditorSide.east)) &&
        open(EditorSide.north) &&
        open(EditorSide.south);
    return vertical
        ? (a: EditorSide.north, b: EditorSide.south)
        : (a: EditorSide.west, b: EditorSide.east);
  }
}
