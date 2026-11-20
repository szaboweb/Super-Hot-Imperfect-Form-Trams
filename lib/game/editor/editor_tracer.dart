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
sealed class EditorRing {
  /// Base constructor for an ordered list of [passes].
  const EditorRing(this.passes);

  /// Creates a closed loop segment of [passes].
  const factory EditorRing.closed(List<EditorPass> passes) = ClosedEditorRing;

  /// Creates an open spur segment between [startStub] and [endStub].
  const factory EditorRing.open(
    List<EditorPass> passes, {
    required EditorStub startStub,
    required EditorStub endStub,
  }) = OpenEditorRing;

  /// Ordered passes traversing this segment.
  final List<EditorPass> passes;

  /// True for closed loops; false for spur segments between two stubs.
  bool get isClosed;

  /// Entry stub when this is an [OpenEditorRing], else null.
  EditorStub? get startStub;

  /// Exit stub when this is an [OpenEditorRing], else null.
  EditorStub? get endStub;

  /// Same segment with pass order, pass directions, and stubs reversed.
  EditorRing get reversed;
}

/// Closed loop segment of rail passes.
final class ClosedEditorRing extends EditorRing {
  /// Creates a closed loop segment from ordered [passes].
  const ClosedEditorRing(super.passes);

  @override
  bool get isClosed => true;

  @override
  EditorStub? get startStub => null;

  @override
  EditorStub? get endStub => null;

  @override
  ClosedEditorRing get reversed =>
      ClosedEditorRing([for (final p in passes.reversed) p.reversed]);
}

/// Open dead-end or wye-stem spur segment between [startStub] and [endStub].
final class OpenEditorRing extends EditorRing {
  /// Creates an open spur segment from [passes], [startStub], and [endStub].
  const OpenEditorRing(
    super.passes, {
    required this.startStub,
    required this.endStub,
  });

  @override
  final EditorStub startStub;

  @override
  final EditorStub endStub;

  @override
  bool get isClosed => false;

  @override
  OpenEditorRing get reversed => OpenEditorRing(
    [for (final p in passes.reversed) p.reversed],
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
      final piece = grid.railAt(cell);
      if (piece != null) _initRail(cell, piece);
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
        else if (_bufferSides[cell] case final sides? when sides.length != 1)
          EditorIssue(EditorMessages.bufferConnections(cell), cell: cell),
    ];
  }

  /// Open ends: every pair side and 3-way Y-switch stub must meet a matching
  /// rail pair, single-connection buffer stop, or Y-switch stub.
  List<EditorStub> openEnds() => [
    for (final cell in _sortedCells()) ...[
      for (final pair in _pairsAt(cell)) ...[
        if (!_isSideConnected(cell, pair.a)) (cell: cell, side: pair.a),
        if (!_isSideConnected(cell, pair.b)) (cell: cell, side: pair.b),
      ],
      if (_wyeStubs[cell] case final stub? when !_isSideConnected(cell, stub))
        (cell: cell, side: stub),
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
      final endStub = ring.endStub;
      assert(allStubs.contains((endStub.cell, endStub.side)));
      result.add(ring);
    }
    for (final cell in _sortedCells()) {
      final pairs = _pairsAt(cell);
      for (var i = 0; i < pairs.length; i++) {
        if (!seenPairs.contains((cell, i))) {
          result.add(_walk(cell, i, seenPairs));
        }
      }
    }
    return result;
  }

  OpenEditorRing _walkStub(
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
    return OpenEditorRing(
      passes,
      startStub: startStub,
      endStub: (cell: next, side: entry),
    );
  }

  ClosedEditorRing _walk(
    EditorCell start,
    int index,
    Set<(EditorCell, int)> seen,
  ) {
    final pair = _pairsAt(start)[index];
    var exit = _startPriority.firstWhere((s) => s == pair.a || s == pair.b);
    var pass = EditorPass(start, exit == pair.a ? pair.b : pair.a, exit);
    final passes = <EditorPass>[];
    while (true) {
      seen.add((pass.cell, _indexOf(pass.cell, pass.from)));
      passes.add(pass);
      final next = _neighbour(pass.cell, pass.to);
      final entry = pass.to.opposite;
      final nextPair = _pairAt(next, entry);
      if (nextPair == null) {
        throw StateError('Unconnected rail pair at $next ($entry)');
      }
      exit = nextPair.a == entry ? nextPair.b : nextPair.a;
      pass = EditorPass(next, entry, exit);
      if (pass.cell == start && _indexOf(next, entry) == index) break;
    }
    return ClosedEditorRing(passes);
  }

  void _initRail(EditorCell cell, EditorPiece piece) {
    if (piece == EditorPiece.bufferStop) return;
    final stem = piece.tStemSide;
    if (stem != null) {
      _initTSwitch(cell, stem);
    } else if (piece.isCrossing) {
      _pairs[cell] = [_hPair, _vPair];
    } else if (piece.isAutoStraight) {
      _pairs[cell] = [grid.isVerticalInline(cell) ? _vPair : _hPair];
    } else {
      _pairs[cell] = [(a: piece.sides[0], b: piece.sides[1])];
    }
  }

  void _initTSwitch(EditorCell cell, EditorSide stem) {
    final missing = stem.opposite;
    for (final s in EditorSide.values) {
      if (s != missing && !_candidateConnectsFrom(cell, s)) {
        _wyeErrors.add(cell);
        return;
      }
    }
    _pairs[cell] = [stem.isHorizontal ? _vPair : _hPair];
    _wyeStubs[cell] = stem;
  }

  bool _candidateConnectsFrom(EditorCell cell, EditorSide s) {
    final n = _neighbour(cell, s);
    final piece = grid.railAt(n);
    if (piece == null) return false;
    if (piece == EditorPiece.bufferStop) {
      return grid.bufferEntrySide(n) == s.opposite;
    }
    return piece.connectsToSide(
      s.opposite,
      verticalInline: grid.isVerticalInline(n),
    );
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
      _pairsAt(cell).indexWhere((p) => p.a == side || p.b == side);

  List<EditorSidePair> _pairsAt(EditorCell cell) {
    final pairs = _pairs[cell];
    if (pairs == null) throw StateError('Missing pairs at $cell');
    return pairs;
  }

  EditorSidePair? _pairAt(EditorCell cell, EditorSide side) {
    for (final p in _pairs[cell] ?? const <EditorSidePair>[]) {
      if (p.a == side || p.b == side) return p;
    }
    return null;
  }
}
