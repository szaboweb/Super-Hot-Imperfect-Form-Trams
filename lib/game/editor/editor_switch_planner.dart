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
  const EditorSwitchPlan(this.crossovers, this.reversedRings, this.errors);

  final List<EditorCrossoverPlan> crossovers;

  /// Rings that must be driven backwards so rectangle lanes run the same way.
  final Set<int> reversedRings;
  final List<String> errors;
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

  final EditorGrid grid;
  final List<EditorRing> rings;
  final Map<(EditorCell, bool), ({int ring, EditorPass pass})> _lanes = {};
  final List<String> _errors = [];
  final List<({int a, int b})> _opposite = [];
  final List<({int a, int b})> _same = [];

  EditorSwitchPlan plan() {
    final plans = <EditorCrossoverPlan>[];
    for (final e in grid.rails.entries) {
      final id = 'sw_${e.key.col}_${e.key.row}';
      final plan = switch (e.value) {
        EditorPiece.switchCircle => _circle(id, e.key),
        EditorPiece.switchTriangle => _triangle(id, e.key),
        EditorPiece.switchRectangle => _rectangle(id, e.key),
        _ => null,
      };
      if (plan != null) plans.add(plan);
    }
    return EditorSwitchPlan(plans, _solveDirections(), _errors);
  }

  EditorCrossoverPlan? _circle(String id, EditorCell cell) {
    final h = _lanes[(cell, true)]!.ring;
    final v = _lanes[(cell, false)]!.ring;
    if (h == v) {
      _errors.add(EditorMessages.circleSameLoop(cell));
      return null;
    }
    return _plan(id, EditorPiece.switchCircle, cell, [h, v]);
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
      final lane = _lanes[(other, horizontal)];
      if (lane == null) continue;
      return _linkLanes(id, cell, other, own, lane);
    }
    _errors.add(EditorMessages.rectNoLane(cell));
    return null;
  }

  EditorCrossoverPlan? _linkLanes(
    String id,
    EditorCell cell,
    EditorCell other,
    ({int ring, EditorPass pass}) own,
    ({int ring, EditorPass pass}) lane,
  ) {
    if (own.ring == lane.ring) {
      _errors.add(EditorMessages.rectSameLoop(cell));
      return null;
    }
    final dot =
        own.pass.to.dCol * lane.pass.to.dCol +
        own.pass.to.dRow * lane.pass.to.dRow;
    (dot < 0 ? _opposite : _same).add((a: own.ring, b: lane.ring));
    final a = grid.cellCenter(cell);
    final b = grid.cellCenter(other);
    return EditorCrossoverPlan(
      id: id,
      piece: EditorPiece.switchRectangle,
      center: math.Point((a.x + b.x) / 2, (a.y + b.y) / 2),
      rings: [own.ring, lane.ring],
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
    final flip = <int, bool>{};
    final edges = [
      for (final e in _opposite) (a: e.a, b: e.b, differ: true),
      for (final e in _same) (a: e.a, b: e.b, differ: false),
    ];
    var changed = true;
    while (changed) {
      changed = false;
      for (final e in edges) {
        changed |= _propagate(flip, e.a, e.b, e.differ);
        changed |= _propagate(flip, e.b, e.a, e.differ);
      }
    }
    for (final e in edges) {
      if (flip[e.a] != null && flip[e.b] != null) {
        if ((flip[e.a] != flip[e.b]) != e.differ) {
          _errors.add(EditorMessages.rectOpposite(_cellOfRings(e.a, e.b)));
        }
      }
    }
    return {
      for (final e in flip.entries)
        if (e.value) e.key,
    };
  }

  bool _propagate(Map<int, bool> flip, int from, int to, bool differ) {
    flip.putIfAbsent(from, () => false);
    if (flip.containsKey(to)) return false;
    flip[to] = differ ? !flip[from]! : flip[from]!;
    return true;
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
}
