import 'dart:math' as math;

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/components/tram_component.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_grid.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_level_builder.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_piece.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_data.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_path.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_ride.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_switch_system.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_turn.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_turn_builder.dart';
import 'package:super_hot_imperfect_form_trams/input/tram_controls.dart';

void main() {
  test(
    'Monte Carlo: 500 random steps across all 3 switch types stay finite',
    () {
      final build = _buildThreeRingLevel();
      expect(build.isValid, isTrue, reason: build.errors.join(', '));
      _simulateLevel(build.level, math.Random(9999), steps: 500);
    },
  );

  test(
    'Monte Carlo (evil): TramComponent SHIFT spam + throttle + cooldown',
    () {
      final level = _buildThreeRingLevel().level;
      final paths = _buildPaths(level);
      final turns = _buildTurns(level, paths);
      final tram = TramComponent(
        path: paths[level.spawns.first.segment]!,
        trackDistance: level.spawns.first.startDistance,
        speed: 160,
        color: const Color(0xFF4CAF50),
        controls: TramControls.wasd,
      )..switches = TurntableSwitchSystem(turns);

      final rng = math.Random(666111);
      const dirs = <math.Point<double>?>[
        null,
        math.Point(0, -1),
        math.Point(0, 1),
        math.Point(-1, 0),
        math.Point(1, 0),
      ];
      for (var i = 0; i < 400; i++) {
        tram.throttle = [-1.0, 0.0, 1.0][rng.nextInt(3)];
        tram.update(0.01 + rng.nextDouble() * 0.04);
        if (rng.nextInt(3) == 0) {
          tram.requestTurn(desiredDirection: dirs[rng.nextInt(dirs.length)]);
        }
        expect(tram.position.x.isFinite && tram.position.y.isFinite, isTrue);
        expect(tram.angle.isFinite && tram.speed.isFinite, isTrue);
      }
    },
  );
}

EditorBuildResult _buildThreeRingLevel() {
  final grid = EditorGrid();
  _drawRing(grid, 1, 1, 5, 5);
  _drawRing(grid, 6, 1, 10, 5);
  _drawRing(grid, 8, 3, 13, 7);
  grid.place(EditorPiece.switchRectangle, (col: 5, row: 2));
  grid.place(EditorPiece.switchCircle, (col: 8, row: 5));
  grid.place(EditorPiece.switchTriangle, (col: 10, row: 3));
  grid.place(EditorPiece.tramGreen, (col: 3, row: 1));
  grid.place(EditorPiece.tramRed, (col: 12, row: 7));
  return const EditorLevelBuilder().build(grid);
}

void _drawRing(EditorGrid g, int c0, int r0, int c1, int r1) {
  g.place(EditorPiece.cornerSE, (col: c0, row: r0));
  g.place(EditorPiece.cornerSW, (col: c1, row: r0));
  g.place(EditorPiece.cornerNE, (col: c0, row: r1));
  g.place(EditorPiece.cornerNW, (col: c1, row: r1));
  for (var c = c0 + 1; c < c1; c++) {
    g.place(EditorPiece.straightH, (col: c, row: r0));
    g.place(EditorPiece.straightH, (col: c, row: r1));
  }
  for (var r = r0 + 1; r < r1; r++) {
    g.place(EditorPiece.straightV, (col: c0, row: r));
    g.place(EditorPiece.straightV, (col: c1, row: r));
  }
}

Map<String, TrackPath> _buildPaths(LevelData level) => {
  for (final s in level.segments)
    if (s.points.length >= 2) s.id: TrackPath(s.points, name: s.id),
};

List<TurntableTurn> _buildTurns(
  LevelData level,
  Map<String, TrackPath> paths,
) => [
  for (final c in level.crossovers)
    for (final l in c.links)
      ...TurntableTurnBuilder.buildAll(
        from: paths[l.from]!,
        to: paths[l.to]!,
        center: c.center,
        radius: c.radius,
        movement: c.movement,
      ),
];

void _simulateLevel(LevelData level, math.Random rng, {required int steps}) {
  final paths = _buildPaths(level);
  final system = TurntableSwitchSystem(_buildTurns(level, paths));
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
      final decision = system.decide(
        path: path,
        distance: distance,
        speed: speed,
        halfLength: 28,
        desiredDirection: dirs[rng.nextInt(dirs.length)],
      );
      ride = decision.ride;
    }
  }
}
