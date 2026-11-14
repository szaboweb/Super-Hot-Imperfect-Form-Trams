import 'dart:math' as math;

import 'editor_grid.dart';
import 'editor_tracer.dart';

/// Turns rings of cell passes into level polylines (world px).
///
/// Straights run edge-midpoint -> cell centre -> edge-midpoint; a corner is a
/// quarter circle of radius tileSize / 2 around the shared cell corner, sampled
/// every ~8 px like the hand-made loops.
class EditorGeometry {
  const EditorGeometry(this.grid, {this.arcSteps = 6});

  final EditorGrid grid;
  final int arcSteps;

  double get _half => grid.tileSize / 2;

  double passLength(EditorPass p) =>
      p.isStraight ? grid.tileSize.toDouble() : _half * math.pi / 2;

  /// Path distance from the ring start to the middle of the pass on [cell].
  double? distanceToCellMiddle(EditorRing ring, EditorCell cell) {
    var along = 0.0;
    for (final p in ring.passes) {
      if (p.cell == cell) return along + passLength(p) / 2;
      along += passLength(p);
    }
    return null;
  }

  /// Closed polyline of [ring] (first point == last point).
  List<math.Point<double>> ringPoints(EditorRing ring) {
    final points = <math.Point<double>>[];
    for (final pass in ring.passes) {
      final part = _passPoints(pass);
      points.addAll(points.isEmpty ? part : part.skip(1));
    }
    points[points.length - 1] = points.first;
    return points;
  }

  List<math.Point<double>> _passPoints(EditorPass p) {
    final c = grid.cellCenter(p.cell);
    final entry = math.Point(
      c.x + p.from.dCol * _half,
      c.y + p.from.dRow * _half,
    );
    final exit = math.Point(c.x + p.to.dCol * _half, c.y + p.to.dRow * _half);
    if (p.isStraight) return [entry, c, exit];
    final corner = math.Point(
      c.x + (p.from.dCol + p.to.dCol) * _half,
      c.y + (p.from.dRow + p.to.dRow) * _half,
    );
    final a0 = math.atan2(entry.y - corner.y, entry.x - corner.x);
    final a1 = math.atan2(exit.y - corner.y, exit.x - corner.x);
    final sweep = math.atan2(math.sin(a1 - a0), math.cos(a1 - a0));
    return [
      for (var i = 0; i <= arcSteps; i++)
        math.Point(
          corner.x + _half * math.cos(a0 + sweep * i / arcSteps),
          corner.y + _half * math.sin(a0 + sweep * i / arcSteps),
        ),
    ];
  }
}
