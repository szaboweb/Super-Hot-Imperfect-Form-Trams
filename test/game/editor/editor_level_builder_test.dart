import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_grid.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_level_builder.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_piece.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_data.dart';

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
}
