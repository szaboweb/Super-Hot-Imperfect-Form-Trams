import 'editor_grid.dart';
import 'editor_messages.dart';
import 'editor_piece.dart';

/// Cell and outward edge where an open rail segment starts or ends.
typedef EditorStub = ({EditorCell cell, EditorSide side});

/// One straight or corner run through a cell, oriented from [from] to [to].
class EditorPass {
  /// Creates a directional pass from [from] to [to] within [cell].
  const EditorPass(this.cell, this.from, this.to);

  final EditorCell cell;
  final EditorSide from;
  final EditorSide to;

  /// True for a straight pass across opposite sides of the cell.
  bool get isStraight => from.opposite == to;

  /// True for a left-right pass (straight only).
  bool get isHorizontal => isStraight && from.isHorizontal;

  /// Same pass traversed in the opposite direction.
  EditorPass get reversed => EditorPass(cell, to, from);
}

/// A closed ring or open dead-end/wye-stem spur of passes (one level segment).
class EditorRing {
  /// Creates a segment of [passes]; open segments carry [startStub] and [endStub].
  const EditorRing(
    this.passes, {
    this.isClosed = true,
    this.startStub,
    this.endStub,
  });

  /// Ordered passes traversing this segment.
  final List<EditorPass> passes;

  /// True for closed loops; false for spur segments between two stubs.
  final bool isClosed;

  /// Entry stub when [isClosed] is false.
  final EditorStub? startStub;

  /// Exit stub when [isClosed] is false.
  final EditorStub? endStub;

  /// Same segment with pass order, pass directions, and stubs reversed.
  EditorRing get reversed => EditorRing(
    [for (final p in passes.reversed) p.reversed],
    isClosed: isClosed,
    startStub: endStub,
    endStub: startStub,
  );
}

/// Pairs of connected sides per cell: what rails do in each cell (no direction).
typedef EditorSidePair = ({EditorSide a, EditorSide b});

/// Reads an [EditorGrid] into connected rings/spurs and reports open ends or
/// invalid junctions.
class EditorTracer {
  /// Traces the rail topology of [grid].
  EditorTracer(this.grid) {
    final cells = grid.rails.keys.toList()..sort(_compareCells);
    for (final cell in cells) {
      _initRail(cell, grid.railAt(cell)!);
    }
    for (final cell in cells) {
      if (grid.railAt(cell) != EditorPiece.bufferStop) continue;
      _bufferSides[cell] = [
        for (final s in EditorSide.values)
          if (_connectsBuffer(_neighbour(cell, s), s.opposite)) s,
      ];
    }
  }

  /// Source grid being traced.
  final EditorGrid grid;
  final Map<EditorCell, List<EditorSidePair>> _pairs = {};
  final Map<EditorCell, EditorSide> _wyeStubs = {};
  final Set<EditorCell> _wyeErrors = {};
  final Map<EditorCell, List<EditorSide>> _bufferSides = {};

  static const _hPair = (a: EditorSide.west, b: EditorSide.east);
  static const _vPair = (a: EditorSide.north, b: EditorSide.south);
  static const _startPriority = [
    EditorSide.east,
    EditorSide.south,
    EditorSide.west,
    EditorSide.north,
  ];

  /// Validation issues for invalid Y-switches and buffer stops, in row-major order.
  List<EditorIssue> junctionIssues() {
    final cells = {..._wyeErrors, ..._bufferSides.keys}.toList()
      ..sort(_compareCells);
    return [
      for (final cell in cells)
        if (_wyeErrors.contains(cell))
          EditorIssue(EditorMessages.wyeConnections(cell), cell: cell)
        else if (_bufferSides[cell]!.length != 1)
          EditorIssue(EditorMessages.bufferConnections(cell), cell: cell),
    ];
  }

  /// Open ends: every pair side and 3-way Y-switch stub must meet a matching
  /// rail pair, single-connection buffer stop, or Y-switch stub.
  List<EditorStub> openEnds() => [
    for (final cell in _sortedCells()) ...[
      for (final pair in _pairs[cell]!)
        for (final side in [pair.a, pair.b])
          if (!_isSideConnected(cell, side)) (cell: cell, side: side),
      if (_wyeStubs[cell] != null && !_isSideConnected(cell, _wyeStubs[cell]!))
        (cell: cell, side: _wyeStubs[cell]!),
    ],
  ];

  bool _isSideConnected(EditorCell cell, EditorSide s) {
    final next = _neighbour(cell, s);
    if (_pairAt(next, s.opposite) != null) return true;
    final buf = _bufferSides[next];
    if (buf != null && buf.length == 1 && buf.single == s.opposite) return true;
    return _wyeStubs[next] == s.opposite;
  }

  /// Open spur segments (stubs first) followed by closed rings in row-major
  /// order. Only call when [junctionIssues] and [openEnds] are empty.
  List<EditorRing> rings() {
    final sortedStubs = [
      for (final e in _bufferSides.entries) (cell: e.key, side: e.value.single),
      for (final e in _wyeStubs.entries) (cell: e.key, side: e.value),
    ]..sort(_compareStubs);
    final allStubs = {for (final s in sortedStubs) (s.cell, s.side)};
    final seenStubs = <(EditorCell, EditorSide)>{};
    final seenPairs = <(EditorCell, int)>{};
    final result = <EditorRing>[];
    for (final stub in sortedStubs) {
      if (seenStubs.contains((stub.cell, stub.side))) continue;
      final ring = _walkStub(stub, seenStubs, seenPairs);
      assert(allStubs.contains((ring.endStub!.cell, ring.endStub!.side)));
      result.add(ring);
    }
    for (final cell in _sortedCells()) {
      final pairs = _pairs[cell]!;
      for (var i = 0; i < pairs.length; i++) {
        if (!seenPairs.contains((cell, i))) {
          result.add(_walk(cell, i, seenPairs));
        }
      }
    }
    return result;
  }

  EditorRing _walkStub(
    EditorStub startStub,
    Set<(EditorCell, EditorSide)> seenStubs,
    Set<(EditorCell, int)> seenPairs,
  ) {
    final passes = <EditorPass>[];
    var next = _neighbour(startStub.cell, startStub.side);
    var entry = startStub.side.opposite;
    while (true) {
      final pair = _pairAt(next, entry);
      if (pair == null) break;
      seenPairs.add((next, _indexOf(next, entry)));
      final exit = pair.a == entry ? pair.b : pair.a;
      passes.add(EditorPass(next, entry, exit));
      next = _neighbour(next, exit);
      entry = exit.opposite;
    }
    seenStubs.addAll([(startStub.cell, startStub.side), (next, entry)]);
    return EditorRing(
      passes,
      isClosed: false,
      startStub: startStub,
      endStub: (cell: next, side: entry),
    );
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

  void _initRail(EditorCell cell, EditorPiece piece) {
    if (piece == EditorPiece.bufferStop) return;
    if (piece == EditorPiece.switchY) return _initWye(cell);
    _pairs[cell] = piece.isCrossing
        ? [_hPair, _vPair]
        : piece.isAutoStraight
        ? [grid.isVerticalInline(cell) ? _vPair : _hPair]
        : [(a: piece.sides[0], b: piece.sides[1])];
  }

  void _initWye(EditorCell cell) {
    final connected = [
      for (final s in EditorSide.values)
        if (_candidateConnectsFrom(cell, s)) s,
    ];
    if (connected.length < 3) {
      _wyeErrors.add(cell);
      return;
    }
    if (connected.length == 4) {
      _pairs[cell] = [_hPair, _vPair];
      return;
    }
    final m = EditorSide.values.firstWhere((s) => !connected.contains(s));
    _pairs[cell] = [m.isHorizontal ? _vPair : _hPair];
    _wyeStubs[cell] = m.opposite;
  }

  bool _candidateConnectsFrom(EditorCell cell, EditorSide s) {
    final n = _neighbour(cell, s);
    final piece = grid.railAt(n);
    if (piece == null) return false;
    if (piece == EditorPiece.bufferStop) {
      return grid.bufferEntrySide(n) == s.opposite;
    }
    if (piece.isCrossing || piece == EditorPiece.switchY) return true;
    if (piece.isAutoStraight) {
      return grid.isVerticalInline(n) ? !s.isHorizontal : s.isHorizontal;
    }
    return piece.sides.contains(s.opposite);
  }

  bool _connectsBuffer(EditorCell n, EditorSide opposite) =>
      _pairAt(n, opposite) != null || _wyeStubs[n] == opposite;

  List<EditorCell> _sortedCells() => _pairs.keys.toList()..sort(_compareCells);

  static int _compareCells(EditorCell x, EditorCell y) =>
      x.row != y.row ? x.row - y.row : x.col - y.col;

  static int _compareStubs(EditorStub a, EditorStub b) {
    final cmp = _compareCells(a.cell, b.cell);
    return cmp != 0 ? cmp : a.side.index - b.side.index;
  }

  EditorCell _neighbour(EditorCell c, EditorSide s) =>
      (col: c.col + s.dCol, row: c.row + s.dRow);

  int _indexOf(EditorCell cell, EditorSide side) =>
      _pairs[cell]!.indexWhere((p) => p.a == side || p.b == side);

  EditorSidePair? _pairAt(EditorCell cell, EditorSide side) {
    for (final p in _pairs[cell] ?? const <EditorSidePair>[]) {
      if (p.a == side || p.b == side) return p;
    }
    return null;
  }
}
