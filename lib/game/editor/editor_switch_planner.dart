import 'dart:math' as math;

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
  });

  final String id;
  final EditorPiece piece;
  final math.Point<double> center;

  /// Distinct ring indices linked (one for a triangle on a single loop, else two).
  final List<int> rings;
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
      for (final p in rings[r].passes) {
        if (p.isStraight) _lanes[(p.cell, p.isHorizontal)] = (ring: r, pass: p);
      }
    }
  }

  static const double _minSwitchDistance = 96.0;

  final EditorGrid grid;
  final List<EditorRing> rings;
  final Map<(EditorCell, bool), ({int ring, EditorPass pass})> _lanes = {};
  final List<EditorIssue> _issues = [];
  final List<({int a, int b})> _opposite = [];
  final List<({int a, int b})> _same = [];

  EditorSwitchPlan plan() {
    final plans = <EditorCrossoverPlan>[];
    final seenCenters = <(int, int)>{};
    for (final e in grid.rails.entries) {
      final id = 'sw_${e.key.col}_${e.key.row}';
      final plan = switch (e.value) {
        EditorPiece.switchCircle => _circle(id, e.key),
        EditorPiece.switchTriangle => _triangle(id, e.key),
        EditorPiece.switchRectangle => _rectangle(id, e.key),
        _ => null,
      };
      if (plan == null) continue;
      if (!seenCenters.add((plan.center.x.round(), plan.center.y.round()))) {
        _issues.add(
          EditorIssue(EditorMessages.rectDuplicate(e.key), cell: e.key),
        );
      } else if (_hasOverlap(plans, plan.center)) {
        _issues.add(
          EditorIssue(EditorMessages.switchOverlap(e.key), cell: e.key),
        );
      } else {
        plans.add(plan);
      }
    }
    final reversed = _solveDirections();
    if (rings.length > 1 && _issues.isEmpty) _checkConnectivity(plans);
    return EditorSwitchPlan(plans, reversed, _issues);
  }

  static bool _hasOverlap(
    List<EditorCrossoverPlan> plans,
    math.Point<double> center,
  ) => plans.any((p) => p.center.distanceTo(center) < _minSwitchDistance);

  EditorCrossoverPlan _circle(String id, EditorCell cell) {
    final h = _lanes[(cell, true)]!.ring;
    final v = _lanes[(cell, false)]!.ring;
    return _plan(id, EditorPiece.switchCircle, cell, h == v ? [h] : [h, v]);
  }

  EditorCrossoverPlan _triangle(String id, EditorCell cell) => _plan(
    id,
    EditorPiece.switchTriangle,
    cell,
    {_lanes[(cell, true)]!.ring, _lanes[(cell, false)]!.ring}.toList(),
  );

  EditorCrossoverPlan? _rectangle(String id, EditorCell cell) {
    final horizontal = _lanes.containsKey((cell, true));
    final own = _lanes[(cell, horizontal)]!;
    final steps = horizontal
        ? [(dCol: 0, dRow: 1), (dCol: 0, dRow: -1)]
        : [(dCol: 1, dRow: 0), (dCol: -1, dRow: 0)];
    for (final s in steps) {
      final other = (col: cell.col + s.dCol, row: cell.row + s.dRow);
      final otherPiece = grid.railAt(other);
      if (otherPiece == null || otherPiece.isCrossing) continue;
      final lane = _lanes[(other, horizontal)];
      if (lane == null) continue;
      return _linkLanes(id, cell, other, own, lane);
    }
    _issues.add(EditorIssue(EditorMessages.rectNoLane(cell), cell: cell));
    return null;
  }

  EditorCrossoverPlan _linkLanes(
    String id,
    EditorCell cell,
    EditorCell other,
    ({int ring, EditorPass pass}) own,
    ({int ring, EditorPass pass}) lane,
  ) {
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
      piece: EditorPiece.switchRectangle,
      center: math.Point((a.x + b.x) / 2, (a.y + b.y) / 2),
      rings: own.ring == lane.ring ? [own.ring] : [own.ring, lane.ring],
    );
  }

  EditorCrossoverPlan _plan(
    String id,
    EditorPiece piece,
    EditorCell cell,
    List<int> ringIds,
  ) => EditorCrossoverPlan(
    id: id,
    piece: piece,
    center: grid.cellCenter(cell),
    rings: ringIds,
  );

  /// 2-colours the rings: rings joined by a rectangle must run the same way.
  Set<int> _solveDirections() {
    final edges = [
      for (final e in _opposite) (a: e.a, b: e.b, differ: true),
      for (final e in _same) (a: e.a, b: e.b, differ: false),
    ];
    final adj = _buildAdjacency(edges);
    final flip = <int, bool>{};
    for (final start in adj.keys) {
      if (!flip.containsKey(start)) _bfsComponent(start, adj, flip);
    }
    _reportConflicts(edges, flip);
    return {
      for (final e in flip.entries)
        if (e.value) e.key,
    };
  }

  static Map<int, List<({int to, bool differ})>> _buildAdjacency(
    List<({int a, int b, bool differ})> edges,
  ) {
    final adj = <int, List<({int to, bool differ})>>{};
    for (final e in edges) {
      (adj[e.a] ??= []).add((to: e.b, differ: e.differ));
      (adj[e.b] ??= []).add((to: e.a, differ: e.differ));
    }
    return adj;
  }

  static void _bfsComponent(
    int start,
    Map<int, List<({int to, bool differ})>> adj,
    Map<int, bool> flip,
  ) {
    flip[start] = false;
    final queue = [start];
    for (var i = 0; i < queue.length; i++) {
      final cur = queue[i];
      final curFlip = flip[cur]!;
      for (final edge in adj[cur]!) {
        if (flip.containsKey(edge.to)) continue;
        flip[edge.to] = edge.differ ? !curFlip : curFlip;
        queue.add(edge.to);
      }
    }
  }

  void _reportConflicts(
    List<({int a, int b, bool differ})> edges,
    Map<int, bool> flip,
  ) {
    final reported = <(int, int)>{};
    for (final e in edges) {
      if ((flip[e.a]! != flip[e.b]!) == e.differ) continue;
      final pair = (math.min(e.a, e.b), math.max(e.a, e.b));
      if (reported.add(pair)) {
        final cell = _cellOfRings(e.a, e.b);
        _issues.add(EditorIssue(EditorMessages.rectOpposite(cell), cell: cell));
      }
    }
  }

  /// Any switch cell linking [a] and [b], to point the message somewhere.
  EditorCell _cellOfRings(int a, int b) {
    for (final e in _lanes.entries) {
      if (grid.railAt(e.key.$1) == EditorPiece.switchRectangle &&
          (e.value.ring == a || e.value.ring == b)) {
        return e.key.$1;
      }
    }
    return (col: 0, row: 0);
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
    final visited = <int>{0};
    final queue = [0];
    for (var i = 0; i < queue.length; i++) {
      for (final next in adj[queue[i]]) {
        if (visited.add(next)) queue.add(next);
      }
    }
    for (var r = 0; r < rings.length; r++) {
      if (!visited.contains(r)) {
        final cell = rings[r].passes.first.cell;
        _issues.add(
          EditorIssue(EditorMessages.disconnectedTrack(cell), cell: cell),
        );
      }
    }
  }
}
