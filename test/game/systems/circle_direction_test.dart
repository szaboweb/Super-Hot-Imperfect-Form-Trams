import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_grid.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_level_builder.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_piece.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_path.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_switch_system.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_turn.dart';
import 'package:super_hot_imperfect_form_trams/input/tram_controls.dart';

void main() {
  test(
    'TramControls.desiredDirectionFor maps WASD and Arrows to screen dir',
    () {
      expect(
        TramControls.wasd.desiredDirectionFor({LogicalKeyboardKey.keyW}),
        const math.Point(0.0, -1.0),
      );
      expect(
        TramControls.wasd.desiredDirectionFor({LogicalKeyboardKey.keyS}),
        const math.Point(0.0, 1.0),
      );
      expect(
        TramControls.wasd.desiredDirectionFor({LogicalKeyboardKey.keyA}),
        const math.Point(-1.0, 0.0),
      );
      expect(
        TramControls.wasd.desiredDirectionFor({LogicalKeyboardKey.keyD}),
        const math.Point(1.0, 0.0),
      );
      expect(
        TramControls.arrows.desiredDirectionFor({LogicalKeyboardKey.arrowUp}),
        const math.Point(0.0, -1.0),
      );
      expect(
        TramControls.arrows.desiredDirectionFor({
          LogicalKeyboardKey.arrowRight,
        }),
        const math.Point(1.0, 0.0),
      );
      expect(TramControls.wasd.desiredDirectionFor({}), isNull);
    },
  );

  test('TurntableSwitchSystem picks North vs South by desiredDirection', () {
    final horiz = TrackPath(const [
      math.Point(-100, 0),
      math.Point(100, 0),
    ], name: 'horiz');
    final vert = TrackPath(const [
      math.Point(0, -100),
      math.Point(0, 100),
    ], name: 'vert');
    final system = TurntableSwitchSystem(
      TurntableTurn.buildAll(
        from: horiz,
        to: vert,
        center: const math.Point(0, 0),
      ),
    );

    final south = system.decide(
      path: horiz,
      distance: 100,
      speed: 120,
      halfLength: 28,
      desiredDirection: const math.Point(0, 1),
    );
    expect(south.isHit, isTrue);
    expect(south.ride!.turn.to.name, 'vert');

    final north = system.decide(
      path: horiz,
      distance: 100,
      speed: 120,
      halfLength: 28,
      desiredDirection: const math.Point(0, -1),
    );
    expect(north.isHit, isTrue);
    expect(north.ride!.turn.to.name, 'vert_rev');
  });

  test(
    'Figure-8 single loop with switchCircle builds and turns both passes',
    () {
      final g = EditorGrid()
        ..place(EditorPiece.switchCircle, (col: 2, row: 2))
        ..place(EditorPiece.cornerSE, (col: 1, row: 1))
        ..place(EditorPiece.cornerSW, (col: 2, row: 1))
        ..place(EditorPiece.cornerNE, (col: 1, row: 2))
        ..place(EditorPiece.cornerSW, (col: 3, row: 2))
        ..place(EditorPiece.cornerNW, (col: 3, row: 3))
        ..place(EditorPiece.cornerNE, (col: 2, row: 3))
        ..place(EditorPiece.tramGreen, (col: 1, row: 1))
        ..place(EditorPiece.tramRed, (col: 3, row: 3));

      final build = const EditorLevelBuilder().build(g);
      expect(build.isValid, isTrue, reason: build.errors.join(', '));
      final level = build.level;
      expect(level.segments.length, 1);
      expect(level.crossovers.length, 1);

      final loop = TrackPath(level.segments.first.points, name: 'loop_1');
      final c = level.crossovers.first;
      final turns = TurntableTurn.buildAll(
        from: loop,
        to: loop,
        center: c.center,
        radius: c.radius,
      );
      final system = TurntableSwitchSystem(turns);
      final crossings = loop.crossingsNear(c.center);
      expect(crossings.length, 2);

      final firstPass = system.decide(
        path: loop,
        distance: crossings[0].along,
        speed: 120,
        halfLength: 28,
      );
      expect(firstPass.isHit, isTrue);
      expect(
        (firstPass.ride!.turn.toAlong - crossings[1].along).abs() < 2 ||
            (firstPass.ride!.turn.toAlong - (loop.length - crossings[1].along))
                    .abs() <
                2,
        isTrue,
      );
    },
  );
}
