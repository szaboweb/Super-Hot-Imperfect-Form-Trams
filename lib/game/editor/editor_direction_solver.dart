import 'dart:math' as math;

import 'editor_grid.dart';
import 'editor_messages.dart';
import 'editor_piece.dart';
import 'editor_tracer.dart';

/// A direction parity constraint between two ring indices [a] and [b].
///
/// When [differ] is true, one ring must be reversed relative to the other so
/// joined parallel switch lanes run in the same direction.
typedef EditorRingConstraint = ({int a, int b, bool differ});

/// Outcome of 2-colouring ring directions across parallel switch lanes.
class EditorDirectionSolution {
  /// Creates a direction solver result with [reversedRings] and [issues].
  const EditorDirectionSolution(this.reversedRings, this.issues);

  /// Ring indices that must be reversed so joined switch lanes align.
  final Set<int> reversedRings;

  /// Conflict issues reported for ring pairs that cannot be aligned.
  final List<EditorIssue> issues;
}

/// 2-colours ring directions so parallel lane switches run in the same way.
class EditorDirectionSolver {
  /// Creates a solver backed by [grid] and straight pass lookup [lanes].
  const EditorDirectionSolver(this.grid, this.lanes);

  /// Source layout used to locate switch cells when reporting conflicts.
  final EditorGrid grid;

  /// Straight pass lookup keyed by `(cell, isHorizontal)`.
  final Map<(EditorCell, bool), ({int ring, EditorPass pass})> lanes;

  /// 2-colours [constraints] into reversed ring indices and conflict [EditorIssue]s.
  EditorDirectionSolution solve(List<EditorRingConstraint> constraints) {
    final adj = <int, List<({int to, bool differ})>>{};
    for (final e in constraints) {
      (adj[e.a] ??= []).add((to: e.b, differ: e.differ));
      (adj[e.b] ??= []).add((to: e.a, differ: e.differ));
    }
    final flip = <int, bool>{};
    for (final start in adj.keys) {
      if (!flip.containsKey(start)) _bfsComponent(start, adj, flip);
    }
    final issues = _reportConflicts(constraints, flip);
    final reversed = {
      for (final e in flip.entries)
        if (e.value) e.key,
    };
    return EditorDirectionSolution(reversed, issues);
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
      final curFlip = flip[cur] ?? false;
      final neighbors = adj[cur] ?? const <({int to, bool differ})>[];
      for (final edge in neighbors) {
        if (flip.containsKey(edge.to)) continue;
        flip[edge.to] = edge.differ ? !curFlip : curFlip;
        queue.add(edge.to);
      }
    }
  }

  List<EditorIssue> _reportConflicts(
    List<EditorRingConstraint> edges,
    Map<int, bool> flip,
  ) {
    final issues = <EditorIssue>[];
    final reported = <(int, int)>{};
    for (final e in edges) {
      final flipA = flip[e.a];
      final flipB = flip[e.b];
      if (flipA == null || flipB == null) continue;
      if ((flipA != flipB) == e.differ) continue;
      final pair = (math.min(e.a, e.b), math.max(e.a, e.b));
      if (reported.add(pair)) {
        final cell = cellOfRings(e.a, e.b);
        issues.add(EditorIssue(EditorMessages.rectOpposite(cell), cell: cell));
      }
    }
    return issues;
  }

  /// Returns a lane-switch cell touching ring [a] or [b] for conflict messages.
  EditorCell cellOfRings(int a, int b) {
    for (final e in lanes.entries) {
      final piece = grid.railAt(e.key.$1);
      final isLaneSwitch =
          piece == EditorPiece.switchRectangle || (piece?.isYSwitch ?? false);
      if (isLaneSwitch && (e.value.ring == a || e.value.ring == b)) {
        return e.key.$1;
      }
    }
    return (col: 0, row: 0);
  }
}
