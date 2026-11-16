import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_grid.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_level_builder.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_piece.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_data.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_path.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_movement.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_turn_builder.dart';

import 'editor_sample_layouts.dart';

void main() {
  const builder = EditorLevelBuilder();

  EditorGrid simpleRing() {
    final g = EditorGrid();
    drawRing(g, 3, 2, 9, 6);
    g.place(EditorPiece.tramGreen, (col: 5, row: 2));
    g.place(EditorPiece.tramRed, (col: 5, row: 6));
    return g;
  }

  test('simple ring becomes one valid closed loop', () {
    final result = builder.build(simpleRing());
    expect(result.errors, isEmpty);
    final json = result.json!;
    final level = LevelData.fromJson(json);
    expect(level.validate(), isEmpty);
    expect(level.segments.length, 1);
    final seg = level.segments.single;
    expect(seg.points.first, seg.points.last);
    expect(seg.nextSegment, seg.id);
    expect(level.spawns.map((s) => s.controls?.name), ['wasd', 'arrows']);
    expect(level.spawns.first.speed, 160);
    expect(level.crossovers, isEmpty);
    expect(json['tileSize'], 64);
  });

  test('trams start on their own cell, along the ring', () {
    final level = builder.build(simpleRing()).level;
    final green = level.spawns.first;
    final red = level.spawns.last;
    expect(green.startDistance, greaterThan(0));
    expect(red.startDistance, greaterThan(green.startDistance));
  });

  test('two crossing rings with circle and triangle validate', () {
    final result = builder.build(crossingRings());
    expect(result.errors, isEmpty);
    final level = result.level;
    expect(level.segments.length, 2);
    expect(level.crossovers.map((c) => c.shape.name).toSet(), {
      'circle',
      'triangle',
    });
    final triangle = level.crossovers.firstWhere(
      (c) => c.shape.name == 'triangle',
    );
    expect(triangle.links.every((l) => l.from == l.to), isTrue);
    expect(triangle.links.length, 2);
  });

  test('rectangle switch joins stacked rings, direction is reconciled', () {
    final result = builder.build(stackedRings());
    expect(result.errors, isEmpty);
    final level = result.level;
    final rect = level.crossovers.single;
    expect(rect.shape.name, 'rectangle');
    expect(
      rect.y,
      closeTo(EditorGrid().cellCenter((col: 5, row: 3)).y + 32, 0.01),
    );
  });

  test('open end is reported per cell and nothing is built', () {
    final g = simpleRing()..remove((col: 6, row: 2));
    final result = builder.build(g);
    expect(result.isValid, isFalse);
    expect(result.json, isNull);
    expect(result.errors.length, 2);
    expect(result.errors.first, contains('Nyitott'));
    expect(result.errors.first, contains('6. oszlop, 3. sor'));
  });

  test('missing trams and empty grid are reported', () {
    expect(builder.build(EditorGrid()).errors, isNotEmpty);
    final g = simpleRing()..remove((col: 5, row: 6));
    expect(builder.build(g).errors.any((e) => e.contains('piros')), isTrue);
  });

  test('rectangle without a parallel lane is an error', () {
    final g = simpleRing()
      ..place(EditorPiece.switchRectangle, (col: 6, row: 2));
    final result = builder.build(g);
    expect(result.errors.single, contains('Téglalap'));
  });

  test('duplicate rectangle switch on the same lane pair is an error', () {
    final g = EditorGrid();
    drawRing(g, 2, 1, 8, 3);
    drawRing(g, 2, 4, 8, 6);
    g
      ..place(EditorPiece.switchRectangle, (col: 5, row: 3))
      ..place(EditorPiece.switchRectangle, (col: 5, row: 4))
      ..place(EditorPiece.tramGreen, (col: 3, row: 1))
      ..place(EditorPiece.tramRed, (col: 3, row: 6));
    final result = builder.build(g);
    expect(result.isValid, isFalse);
    expect(
      result.errors.any((e) => e.contains('már van egy téglalap kitérő')),
      isTrue,
    );
  });

  test('3-ring chain with opposite and same links reconciles cleanly', () {
    final g = EditorGrid();
    drawRing(g, 2, 0, 12, 2);
    drawRing(g, 2, 3, 12, 9);
    drawRing(g, 4, 4, 10, 7);
    g
      ..place(EditorPiece.switchRectangle, (col: 7, row: 2))
      ..place(EditorPiece.switchRectangle, (col: 5, row: 4))
      ..place(EditorPiece.tramGreen, (col: 3, row: 0))
      ..place(EditorPiece.tramRed, (col: 3, row: 9));
    final result = builder.build(g);
    expect(result.errors, isEmpty);
    expect(result.level.validate(), isEmpty);
  });

  test('odd conflicting 3-ring cycle fails with rectOpposite', () {
    final g = EditorGrid();
    drawRing(g, 1, 1, 6, 4);
    drawRing(g, 7, 1, 12, 4);
    drawRing(g, 1, 5, 12, 8);
    g
      ..place(EditorPiece.switchRectangle, (col: 6, row: 2))
      ..place(EditorPiece.switchRectangle, (col: 3, row: 4))
      ..place(EditorPiece.switchRectangle, (col: 9, row: 4))
      ..place(EditorPiece.tramGreen, (col: 2, row: 1))
      ..place(EditorPiece.tramRed, (col: 8, row: 1));
    final result = builder.build(g);
    expect(result.isValid, isFalse);
    expect(result.errors.length, 1);
    expect(result.errors.single, contains('ellentétes irányú'));
  });

  test('two adjacent circle switches (< 96 px) fail with switchOverlap', () {
    final g = EditorGrid();
    drawRing(g, 2, 1, 7, 5);
    drawRing(g, 4, 2, 5, 7);
    g
      ..place(EditorPiece.switchCircle, (col: 4, row: 5))
      ..place(EditorPiece.switchCircle, (col: 5, row: 5))
      ..place(EditorPiece.tramGreen, (col: 3, row: 1))
      ..place(EditorPiece.tramRed, (col: 4, row: 7));
    final result = builder.build(g);
    expect(result.isValid, isFalse);
    expect(result.errors.any((e) => e.contains('Átfedő váltók')), isTrue);
  });

  test('two adjacent rectangle switches (< 96 px) fail with switchOverlap', () {
    final g = EditorGrid();
    drawRing(g, 2, 1, 8, 3);
    drawRing(g, 2, 4, 8, 6);
    g
      ..place(EditorPiece.switchRectangle, (col: 4, row: 3))
      ..place(EditorPiece.switchRectangle, (col: 5, row: 3))
      ..place(EditorPiece.tramGreen, (col: 3, row: 1))
      ..place(EditorPiece.tramRed, (col: 3, row: 6));
    final result = builder.build(g);
    expect(result.isValid, isFalse);
    expect(result.errors.any((e) => e.contains('Átfedő váltók')), isTrue);
  });

  test('rectangle adjacent to circle or triangle fails with switchOverlap', () {
    for (final crossing in [
      EditorPiece.switchCircle,
      EditorPiece.switchTriangle,
    ]) {
      final g = EditorGrid();
      drawRing(g, 2, 1, 8, 3);
      drawRing(g, 0, 0, 6, 4);
      g
        ..place(EditorPiece.switchCircle, (col: 6, row: 1))
        ..place(crossing, (col: 6, row: 3))
        ..place(EditorPiece.switchRectangle, (col: 5, row: 3))
        ..place(EditorPiece.tramGreen, (col: 3, row: 1))
        ..place(EditorPiece.tramRed, (col: 2, row: 4));
      final result = builder.build(g);
      expect(result.isValid, isFalse);
      expect(result.json, isNull);
      expect(result.errors.any((e) => e.contains('Átfedő váltók')), isTrue);
    }
  });

  test('two unlinked loops fail with disconnectedTrack', () {
    final g = EditorGrid();
    drawRing(g, 1, 1, 3, 3);
    drawRing(g, 5, 1, 7, 3);
    g
      ..place(EditorPiece.tramGreen, (col: 2, row: 1))
      ..place(EditorPiece.tramRed, (col: 6, row: 1));
    final result = builder.build(g);
    expect(result.isValid, isFalse);
    expect(result.errors.any((e) => e.contains('Különálló pályarész')), isTrue);
  });

  test('crossing loops joined only by switchTriangle fail disconnected', () {
    final g = EditorGrid();
    drawRing(g, 1, 1, 5, 5);
    drawRing(g, 3, 3, 7, 7);
    g
      ..place(EditorPiece.switchTriangle, (col: 5, row: 3))
      ..place(EditorPiece.switchTriangle, (col: 3, row: 5))
      ..place(EditorPiece.tramGreen, (col: 2, row: 1))
      ..place(EditorPiece.tramRed, (col: 6, row: 7));
    final result = builder.build(g);
    expect(result.isValid, isFalse);
    expect(result.errors.any((e) => e.contains('Különálló pályarész')), isTrue);
  });

  test('rectangle next to crossing never emits 32px or 91px slide', () {
    final noLane = crossingRings()
      ..place(EditorPiece.switchRectangle, (col: 7, row: 4));
    final rejected = builder.build(noLane);
    expect(rejected.isValid, isFalse);
    expect(rejected.json, isNull);
    expect(rejected.errors.any((e) => e.contains('Téglalap kitérő')), isTrue);

    final valid = EditorGrid();
    drawRing(valid, 1, 1, 2, 3);
    drawRing(valid, 3, 1, 4, 3);
    valid
      ..place(EditorPiece.switchRectangle, (col: 2, row: 2))
      ..place(EditorPiece.tramGreen, (col: 1, row: 1))
      ..place(EditorPiece.tramRed, (col: 4, row: 1));
    final built = builder.build(valid);
    expect(built.isValid, isTrue);
    final level = built.level;
    final paths = {
      for (final s in level.segments) s.id: TrackPath(s.points, name: s.id),
    };
    final rect = level.crossovers.single;
    final turns = [
      for (final l in rect.links)
        ...TurntableTurnBuilder.buildAll(
          from: paths[l.from]!,
          to: paths[l.to]!,
          center: rect.center,
          radius: rect.radius,
          movement: TurntableMovement.slide,
        ),
    ];
    expect(turns, isNotEmpty);
    for (final t in turns) {
      expect(t.slideDistance, inInclusiveRange(54.0, 70.0));
    }
  });
}
