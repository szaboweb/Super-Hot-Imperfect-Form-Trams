import 'dart:math' as math;

import 'editor_grid.dart';
import 'editor_piece.dart';
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
    var along = ring is OpenEditorRing ? _half : 0.0;
    for (final p in ring.passes) {
      if (p.cell == cell) return along + passLength(p) / 2;
      along += passLength(p);
    }
    return null;
  }

  /// Polyline of [ring] (closed when [ClosedEditorRing], else center-to-center
  /// between [OpenEditorRing.startStub] and [OpenEditorRing.endStub]).
  List<math.Point<double>> ringPoints(EditorRing ring) {
    switch (ring) {
      case OpenEditorRing(:final startStub, :final endStub, :final passes):
        final points = <math.Point<double>>[
          grid.cellCenter(startStub.cell),
          _edgeMidpoint(startStub.cell, startStub.side),
        ];
        for (final pass in passes) {
          points.addAll(_passPoints(pass).skip(1));
        }
        points.add(grid.cellCenter(endStub.cell));
        return points;
      case ClosedEditorRing(:final passes):
        final points = <math.Point<double>>[];
        for (final pass in passes) {
          final part = _passPoints(pass);
          points.addAll(points.isEmpty ? part : part.skip(1));
        }
        points[points.length - 1] = points.first;
        return points;
    }
  }

  math.Point<double> _edgeMidpoint(EditorCell cell, EditorSide side) {
    final c = grid.cellCenter(cell);
    return math.Point(c.x + side.dCol * _half, c.y + side.dRow * _half);
  }

  List<math.Point<double>> _passPoints(EditorPass p) {
    final c = grid.cellCenter(p.cell);
    final entry = _edgeMidpoint(p.cell, p.from);
    final exit = _edgeMidpoint(p.cell, p.to);
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
