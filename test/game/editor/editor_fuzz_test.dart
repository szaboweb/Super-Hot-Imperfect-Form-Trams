import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_controller.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_grid.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_level_builder.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_piece.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_data.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_path.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_movement.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_ride.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_switch_system.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_turn.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_turn_builder.dart';

import 'editor_sample_layouts.dart';

void main() {
  test('Monte Carlo: random editor edits never crash EditorLevelBuilder', () {
    final rng = math.Random(20261116);
    const builder = EditorLevelBuilder();
    for (var trial = 0; trial < 300; trial++) {
      final grid = EditorGrid();
      final ops = 5 + rng.nextInt(35);
      for (var step = 0; step < ops; step++) {
        _applyRandomEdit(grid, rng);
      }
      final result = builder.build(EditorGrid.fromJson(grid.toJson()));
      if (result.isValid) {
        expect(result.level.segments, isNotEmpty);
        expect(result.level.spawns.length, 2);
      } else {
        expect(result.errors, isNotEmpty);
      }
    }
  });

  test(
    'Monte Carlo: random multi-ring + switch layouts build or fail cleanly',
    () {
      final rng = math.Random(424242);
      const builder = EditorLevelBuilder();
      for (var trial = 0; trial < 150; trial++) {
        final grid = EditorGrid();
        final ringCount = 1 + rng.nextInt(3);
        for (var r = 0; r < ringCount; r++) {
          final c0 = rng.nextInt(grid.cols - 3);
          final r0 = rng.nextInt(grid.rows - 3);
          final c1 = c0 + 1 + rng.nextInt(math.min(5, grid.cols - 1 - c0));
          final r1 = r0 + 1 + rng.nextInt(math.min(4, grid.rows - 1 - r0));
          drawRing(grid, c0, r0, c1, r1);
        }
        _placeSwitchesAndTrams(grid, rng, 3);
        _verifyBuild(builder.build(grid), grid.tileSize.toDouble(), rng, 60);
      }
    },
  );

  test(
    'Monte Carlo (evil): illogical crammed switches & near-valid mutations',
    () {
      final rng = math.Random(777888);
      const builder = EditorLevelBuilder();
      for (var trial = 0; trial < 200; trial++) {
        final grid = EditorGrid();
        drawRing(grid, 2, 2, 4 + rng.nextInt(4), 3 + rng.nextInt(3));
        if (rng.nextBool()) {
          drawRing(grid, 2, 4 + rng.nextInt(2), 5 + rng.nextInt(3), 7);
        }
        _placeSwitchesAndTrams(grid, rng, 2 + rng.nextInt(6));
        _verifyBuild(builder.build(grid), grid.tileSize.toDouble(), rng, 80);
      }
    },
  );

  test('Monte Carlo (evil): tiny rings + dense rectangle switches + EditorController', () {
    final rng = math.Random(13371337);
    for (var trial = 0; trial < 150; trial++) {
      final ctrl = EditorController();
      drawRing(ctrl.grid, 2, 2, 3 + rng.nextInt(3), 3 + rng.nextInt(2));
      final straights = [
        for (final e in ctrl.grid.rails.entries)
          if (e.value == EditorPiece.straightH ||
              e.value == EditorPiece.straightV)
            e.key,
      ];
      for (var i = 0; i < 4 && straights.isNotEmpty; i++) {
        ctrl.selectPiece(EditorPiece.switchRectangle);
        ctrl.handleCellTap(straights[rng.nextInt(straights.length)]);
      }
      final all = ctrl.grid.rails.keys.toList();
      if (all.length >= 2) {
        ctrl.selectPiece(EditorPiece.tramGreen);
        ctrl.handleCellTap(all[rng.nextInt(all.length)]);
        ctrl.selectPiece(EditorPiece.tramRed);
        ctrl.handleCellTap(all[rng.nextInt(all.length)]);
      }
      final res = ctrl.buildLevel();
      if (res.isValid) {
        _verifyLevel(res.level, ctrl.grid.tileSize.toDouble(), rng, 60);
      }
      ctrl.dispose();
    }
  });
}

void _applyRandomEdit(EditorGrid grid, math.Random rng) {
  const pieces = EditorPiece.values;
  final cell = (
    col: rng.nextInt(grid.cols + 2) - 1,
    row: rng.nextInt(grid.rows + 2) - 1,
  );
  switch (rng.nextInt(5)) {
    case 0 || 1:
      grid.place(pieces[rng.nextInt(pieces.length)], cell);
    case 2:
      grid.move(cell, (
        col: rng.nextInt(grid.cols),
        row: rng.nextInt(grid.rows),
      ));
    case 3:
      grid.remove(cell);
    default:
      if (rng.nextInt(10) == 0) grid.clear();
  }
}

void _placeSwitchesAndTrams(EditorGrid grid, math.Random rng, int switchCount) {
  final cells = grid.rails.keys.toList();
  for (final c in cells) {
    if (_isFourWayCrossing(grid, c) && rng.nextInt(10) < 9) {
      grid.place(
        rng.nextInt(4) == 0
            ? EditorPiece.switchTriangle
            : EditorPiece.switchCircle,
        c,
      );
    }
  }
  final parallels = cells.where((c) => _hasParallelStraight(grid, c)).toList();
  if (parallels.isNotEmpty && rng.nextInt(10) < 8) {
    grid.place(
      EditorPiece.switchRectangle,
      parallels[rng.nextInt(parallels.length)],
    );
  }
  if (switchCount > 3 || rng.nextInt(4) == 0) {
    const sw = [
      EditorPiece.switchCircle,
      EditorPiece.switchTriangle,
      EditorPiece.switchRectangle,
    ];
    for (var i = 0; i < switchCount && cells.isNotEmpty; i++) {
      grid.place(sw[rng.nextInt(3)], cells[rng.nextInt(cells.length)]);
    }
  }
  final plain = cells.where((c) => grid.railAt(c)!.isPlainRail).toList();
  final tramCells = plain.length >= 2 ? plain : cells;
  if (tramCells.length >= 2) {
    final g = rng.nextInt(tramCells.length);
    final r = (g + 1 + rng.nextInt(tramCells.length - 1)) % tramCells.length;
    grid
      ..place(EditorPiece.tramGreen, tramCells[g])
      ..place(EditorPiece.tramRed, tramCells[r]);
  }
}

bool _isFourWayCrossing(EditorGrid grid, EditorCell cell) {
  for (final side in EditorSide.values) {
    final p = grid.railAt((
      col: cell.col + side.dCol,
      row: cell.row + side.dRow,
    ));
    if (p == null || (!p.isCrossing && !p.sides.contains(side.opposite))) {
      return false;
    }
  }
  return true;
}

bool _hasParallelStraight(EditorGrid grid, EditorCell cell) {
  final p = grid.railAt(cell);
  if (p != EditorPiece.straightH && p != EditorPiece.straightV) return false;
  final d = p == EditorPiece.straightH ? (0, 1) : (1, 0);
  return grid.railAt((col: cell.col + d.$1, row: cell.row + d.$2)) == p ||
      grid.railAt((col: cell.col - d.$1, row: cell.row - d.$2)) == p;
}

void _verifyBuild(
  EditorBuildResult result,
  double tileSize,
  math.Random rng,
  int steps,
) {
  if (result.isValid) {
    _verifyLevel(result.level, tileSize, rng, steps);
  } else {
    expect(result.errors, isNotEmpty);
  }
}

void _verifyLevel(
  LevelData level,
  double tileSize,
  math.Random rng,
  int steps,
) {
  _assertNonOverlapping(level);
  _assertConnectedSegments(level);
  final paths = {
    for (final s in level.segments)
      if (s.points.length >= 2) s.id: TrackPath(s.points, name: s.id),
  };
  final turns = <TurntableTurn>[];
  for (final c in level.crossovers) {
    for (final l in c.links) {
      final built = TurntableTurnBuilder.buildAll(
        from: paths[l.from]!,
        to: paths[l.to]!,
        center: c.center,
        radius: c.radius,
        movement: c.movement,
      );
      _assertSlideInvariants(built, tileSize, c.id);
      turns.addAll(built);
    }
  }
  _simulateSteps(paths, TurntableSwitchSystem(turns), level, rng, steps);
}

void _assertNonOverlapping(LevelData level) {
  final list = level.crossovers;
  for (var i = 0; i < list.length; i++) {
    for (var j = i + 1; j < list.length; j++) {
      final gap = list[i].center.distanceTo(list[j].center);
      expect(gap, greaterThanOrEqualTo(96.0 - 1e-6));
    }
  }
}

void _assertConnectedSegments(LevelData level) {
  final adj = <String, Set<String>>{
    for (final s in level.segments) s.id: <String>{},
  };
  for (final c in level.crossovers) {
    if (c.movement == TurntableMovement.reverse) continue;
    for (final l in c.links) {
      adj[l.from]?.add(l.to);
      adj[l.to]?.add(l.from);
    }
  }
  final start = level.spawns.first.segment;
  final visited = <String>{start};
  final queue = [start];
  for (var i = 0; i < queue.length; i++) {
    for (final next in adj[queue[i]] ?? const <String>{}) {
      if (visited.add(next)) queue.add(next);
    }
  }
  expect(visited, containsAll(level.segments.map((s) => s.id)));
}

void _assertSlideInvariants(
  List<TurntableTurn> turns,
  double tileSize,
  String id,
) {
  for (final t in turns) {
    if (t.movement == TurntableMovement.slide) {
      expect(
        t.slideDistance,
        inInclusiveRange(tileSize - 10, tileSize + 6),
        reason: 'Bad slide distance ${t.slideDistance} at $id',
      );
      expect(t.sweep.abs(), lessThan(0.01));
    }
  }
}

void _simulateSteps(
  Map<String, TrackPath> paths,
  TurntableSwitchSystem system,
  LevelData level,
  math.Random rng,
  int steps,
) {
  const dirs = <math.Point<double>?>[
    null,
    math.Point(0, -1),
    math.Point(0, 1),
    math.Point(-1, 0),
    math.Point(1, 0),
  ];
  var path = paths[level.spawns.first.segment]!;
  var distance = level.spawns.first.startDistance;
  TurntableRide? ride;
  for (var i = 0; i < steps; i++) {
    final dt = 0.01 + rng.nextDouble() * 0.04;
    final speed = rng.nextInt(8) == 0 ? -80.0 : 60.0 + rng.nextDouble() * 180.0;
    if (ride != null) {
      ride.advance(dt, speed.abs().clamp(40.0, 240.0));
      expect(ride.position.x.isFinite && ride.position.y.isFinite, isTrue);
      expect(ride.heading.isFinite, isTrue);
      if (ride.finished) {
        path = ride.exitPath;
        distance = path.normalize(ride.exitDistance);
        ride = null;
      }
      continue;
    }
    distance = path.normalize(distance + speed * dt);
    final pos = path.positionAt(distance);
    expect(pos.x.isFinite && pos.y.isFinite, isTrue);
    if (rng.nextInt(3) == 0 && speed > 0) {
      ride = system
          .decide(
            path: path,
            distance: distance,
            speed: speed,
            halfLength: 28,
            desiredDirection: dirs[rng.nextInt(dirs.length)],
          )
          .ride;
    }
  }
}
