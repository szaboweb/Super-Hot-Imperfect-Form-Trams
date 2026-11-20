import 'dart:math' as math;

import 'editor_direction_solver.dart';
import 'editor_grid.dart';
import 'editor_messages.dart';
import 'editor_piece.dart';
import 'editor_tracer.dart';

/// A crossover to emit: the ring indices it links (`ringB == ringA` for a triangle).
class EditorCrossoverPlan {
  const EditorCrossoverPlan({
    required this.id,
    required this.piece,
    required this.center,
    required this.rings,
    this.radius = 48,
    this.stemCenter,
    this.forwardSide,
  });

  final String id;
  final EditorPiece piece;
  final math.Point<double> center;

  /// Distinct ring indices linked (one for a triangle on a single loop, else two).
  final List<int> rings;

  /// Crossover platform radius in world px.
  final double radius;

  /// Stem cell centre for [EditorPiece.isYSwitch] (`turnout`).
  final math.Point<double>? stemCenter;

  /// Diverging travel direction for [EditorPiece.isYSwitch] (`turnout`).
  final EditorSide? forwardSide;
}

/// Outcome of planning the switches of a layout.
class EditorSwitchPlan {
  const EditorSwitchPlan(this.crossovers, this.reversedRings, this.issues);

  final List<EditorCrossoverPlan> crossovers;

  /// Rings that must be driven backwards so rectangle lanes run the same way.
  final Set<int> reversedRings;
  final List<EditorIssue> issues;

  List<String> get errors => [for (final i in issues) i.message];
}

/// Decides, per switch piece, which rings it links (see GAME_DESIGN "Editor").
///
/// Rules: circle / triangle sit on a crossing cell (the horizontal and vertical
/// pass belong to the two loops); a rectangle sits on a straight cell and
/// slides to the straight rail of the same axis in the cell directly below it
/// (horizontal) or to its right (vertical), else above / to its left. The
/// platform centre is halfway between the two cell centres, so the lane pitch is
/// the tile size and the engine derives the slide distance from the geometry.
class EditorSwitchPlanner {
  EditorSwitchPlanner(this.grid, this.rings) {
    for (var r = 0; r < rings.length; r++) {
      final ring = rings[r];
      if (!ring.isClosed) {
        final start = _require(ring.startStub, 'startStub on ring $r');
        final end = _require(ring.endStub, 'endStub on ring $r');
        _stubRings[(start.cell, start.side)] = r;
        _stubRings[(end.cell, end.side)] = r;
      }
      for (final p in ring.passes) {
        if (p.isStraight) _lanes[(p.cell, p.isHorizontal)] = (ring: r, pass: p);
      }
    }
  }

  final EditorGrid grid;
  final List<EditorRing> rings;
  final Map<(EditorCell, bool), ({int ring, EditorPass pass})> _lanes = {};
  final Map<(EditorCell, EditorSide), int> _stubRings = {};
  final List<EditorIssue> _issues = [];
  final List<({int a, int b})> _opposite = [];
  final List<({int a, int b})> _same = [];

  EditorSwitchPlan plan() {
    final plans = <EditorCrossoverPlan>[];
    final seenCenters = <(int, int)>{};
    for (final e in grid.rails.entries) {
      final id = 'sw_${e.key.col}_${e.key.row}';
      final plan = switch (e.value) {
        EditorPiece.switchCircle ||
        EditorPiece.switchTriangle => _crossing(id, e.key, e.value),
        EditorPiece.switchRectangle => _rectangle(id, e.key),
        _ when e.value.isTSwitch => _tSwitch(id, e.key, e.value),
        _ when e.value.isYSwitch => _ySwitch(id, e.key, e.value),
        _ => null,
      };
      if (plan == null) continue;
      if (!seenCenters.add((plan.center.x.round(), plan.center.y.round()))) {
        _issues.add(
          EditorIssue(EditorMessages.rectDuplicate(e.key), cell: e.key),
        );
      } else if (plans.any(
        (p) => p.center.distanceTo(plan.center) < p.radius + plan.radius - 0.5,
      )) {
        _issues.add(
          EditorIssue(EditorMessages.switchOverlap(e.key), cell: e.key),
        );
      } else {
        plans.add(plan);
      }
    }
    final solution = EditorDirectionSolver(grid, _lanes).solve([
      for (final e in _opposite) (a: e.a, b: e.b, differ: true),
      for (final e in _same) (a: e.a, b: e.b, differ: false),
    ]);
    _issues.addAll(solution.issues);
    if (rings.length > 1 && _issues.isEmpty) _checkConnectivity(plans);
    return EditorSwitchPlan(plans, solution.reversedRings, _issues);
  }

  EditorCrossoverPlan _crossing(String id, EditorCell cell, EditorPiece piece) {
    final h = _requireLane(cell, true).ring;
    final v = _requireLane(cell, false).ring;
    return _plan(id, piece, cell, h == v ? [h] : [h, v]);
  }

  EditorCrossoverPlan _tSwitch(String id, EditorCell cell, EditorPiece piece) {
    final stem = _require(piece.tStemSide, 'tStemSide at $cell');
    final throughRing = _requireLane(cell, !stem.isHorizontal).ring;
    final stemRing = _require(_stubRings[(cell, stem)], 'stem ring at $cell');
    final rings = throughRing == stemRing
        ? [throughRing]
        : [throughRing, stemRing];
    return _plan(id, piece, cell, rings, radius: 32);
  }

  EditorCrossoverPlan? _ySwitch(String id, EditorCell cell, EditorPiece piece) {
    final fwd = _require(piece.yForwardSide, 'yForwardSide at $cell');
    final branch = _require(piece.yBranchSide, 'yBranchSide at $cell');
    final own = _requireLane(cell, fwd.isHorizontal);
    final other = (col: cell.col + branch.dCol, row: cell.row + branch.dRow);
    final otherPiece = grid.railAt(other);
    final lane = (otherPiece != null && !otherPiece.isCrossing)
        ? _lanes[(other, fwd.isHorizontal)]
        : null;
    if (lane == null) {
      _issues.add(EditorIssue(EditorMessages.ySwitchNoLane(cell), cell: cell));
      return null;
    }
    return _linkLanes(
      id,
      piece,
      cell,
      other,
      own,
      lane,
      stemCenter: grid.cellCenter(cell),
      forwardSide: fwd,
    );
  }

  EditorCrossoverPlan? _rectangle(String id, EditorCell cell) {
    final horizontal = _lanes.containsKey((cell, true));
    final own = _requireLane(cell, horizontal);
    final steps = horizontal
        ? [(dCol: 0, dRow: 1), (dCol: 0, dRow: -1)]
        : [(dCol: 1, dRow: 0), (dCol: -1, dRow: 0)];
    for (final s in steps) {
      final other = (col: cell.col + s.dCol, row: cell.row + s.dRow);
      final otherPiece = grid.railAt(other);
      if (otherPiece == null || otherPiece.isCrossing) continue;
      final lane = _lanes[(other, horizontal)];
      if (lane == null) continue;
      return _linkLanes(
        id,
        EditorPiece.switchRectangle,
        cell,
        other,
        own,
        lane,
      );
    }
    _issues.add(EditorIssue(EditorMessages.rectNoLane(cell), cell: cell));
    return null;
  }

  EditorCrossoverPlan _linkLanes(
    String id,
    EditorPiece piece,
    EditorCell cell,
    EditorCell other,
    ({int ring, EditorPass pass}) own,
    ({int ring, EditorPass pass}) lane, {
    math.Point<double>? stemCenter,
    EditorSide? forwardSide,
  }) {
    if (own.ring != lane.ring) {
      final dot =
          own.pass.to.dCol * lane.pass.to.dCol +
          own.pass.to.dRow * lane.pass.to.dRow;
      (dot < 0 ? _opposite : _same).add((a: own.ring, b: lane.ring));
    }
    final a = grid.cellCenter(cell);
    final b = grid.cellCenter(other);
    return EditorCrossoverPlan(
      id: id,
      piece: piece,
      center: math.Point((a.x + b.x) / 2, (a.y + b.y) / 2),
      rings: own.ring == lane.ring ? [own.ring] : [own.ring, lane.ring],
      stemCenter: stemCenter,
      forwardSide: forwardSide,
    );
  }

  EditorCrossoverPlan _plan(
    String id,
    EditorPiece piece,
    EditorCell cell,
    List<int> ringIds, {
    double radius = 48,
  }) => EditorCrossoverPlan(
    id: id,
    piece: piece,
    center: grid.cellCenter(cell),
    rings: ringIds,
    radius: radius,
  );

  ({int ring, EditorPass pass}) _requireLane(EditorCell cell, bool horizontal) {
    final lane = _lanes[(cell, horizontal)];
    if (lane == null) {
      final axis = horizontal ? 'horizontal' : 'vertical';
      throw StateError('Missing $axis lane at $cell');
    }
    return lane;
  }

  static T _require<T>(T? value, String detail) {
    if (value == null) throw StateError('Missing $detail');
    return value;
  }

  void _checkConnectivity(List<EditorCrossoverPlan> plans) {
    final adj = List.generate(rings.length, (_) => <int>[]);
    for (final p in plans) {
      if (p.piece == EditorPiece.switchTriangle || p.rings.length < 2) {
        continue;
      }
      adj[p.rings[0]].add(p.rings[1]);
      adj[p.rings[1]].add(p.rings[0]);
    }
    for (final e in grid.rails.entries) {
      if (e.value != EditorPiece.crossing) continue;
      final h = _requireLane(e.key, true).ring;
      final v = _requireLane(e.key, false).ring;
      if (h == v) continue;
      adj[h].add(v);
      adj[v].add(h);
    }
    final visited = <int>{0};
    final queue = [0];
    for (var i = 0; i < queue.length; i++) {
      for (final next in adj[queue[i]]) {
        if (visited.add(next)) queue.add(next);
      }
    }
    for (var r = 0; r < rings.length; r++) {
      if (!visited.contains(r)) {
        final ring = rings[r];
        final cell = ring.passes.isNotEmpty
            ? ring.passes.first.cell
            : _require(ring.startStub, 'startStub on ring $r').cell;
        _issues.add(
          EditorIssue(EditorMessages.disconnectedTrack(cell), cell: cell),
        );
      }
    }
  }
}
