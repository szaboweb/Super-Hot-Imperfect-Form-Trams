import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_grid.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_level_builder.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_piece.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/crossover_data.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/track_zone_data.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_graph.dart';

import 'editor_sample_layouts.dart';

void main() {
  const builder = EditorLevelBuilder();

  test(
    'crossing loops joined only via passive crossing build 0 crossovers',
    () {
      final g = EditorGrid();
      drawRing(g, 2, 2, 8, 6);
      drawRing(g, 6, 4, 12, 8);
      g.place(EditorPiece.crossing, (col: 8, row: 4));
      g.place(EditorPiece.crossing, (col: 6, row: 6));
      g.place(EditorPiece.tramGreen, (col: 4, row: 2));
      g.place(EditorPiece.tramRed, (col: 9, row: 8));

      final result = builder.build(g);
      expect(result.isValid, isTrue, reason: result.errors.join('; '));
      expect(result.level.segments, hasLength(2));
      expect(result.level.crossovers, isEmpty);
    },
  );

  group('bufferStop and tram blocking', () {
    test(
      'open spur between bufferStops linked via switchCircle builds deadEnd',
      () {
        final g = EditorGrid();
        drawRing(g, 2, 2, 8, 6);
        g.place(EditorPiece.bufferStop, (col: 6, row: 4));
        g.place(EditorPiece.straightH, (col: 7, row: 4));
        g.place(EditorPiece.switchCircle, (col: 8, row: 4));
        g.place(EditorPiece.straightH, (col: 9, row: 4));
        g.place(EditorPiece.bufferStop, (col: 10, row: 4));
        g.place(EditorPiece.tramGreen, (col: 4, row: 2));
        g.place(EditorPiece.tramRed, (col: 4, row: 6));

        final result = builder.build(g);
        expect(result.isValid, isTrue, reason: result.errors.join('; '));
        expect(
          result.level.segments.any((s) => s.end == TrackEnd.deadEnd),
          isTrue,
        );
        expect(result.level.crossovers, hasLength(1));
      },
    );

    test('bufferStop with 0 or 2 neighbours fails with Ütközőbak', () {
      final isolated = EditorGrid();
      drawRing(isolated, 2, 2, 8, 6);
      isolated.place(EditorPiece.bufferStop, (col: 10, row: 4));
      isolated.place(EditorPiece.tramGreen, (col: 4, row: 2));
      isolated.place(EditorPiece.tramRed, (col: 4, row: 6));
      final resZero = builder.build(isolated);
      expect(resZero.isValid, isFalse);
      expect(resZero.errors.join(' '), contains('Ütközőbak'));

      final twoNeighbours = EditorGrid();
      drawRing(twoNeighbours, 2, 2, 8, 6);
      twoNeighbours.place(EditorPiece.bufferStop, (col: 4, row: 2));
      twoNeighbours.place(EditorPiece.tramGreen, (col: 5, row: 2));
      twoNeighbours.place(EditorPiece.tramRed, (col: 4, row: 6));
      final resTwo = builder.build(twoNeighbours);
      expect(resTwo.isValid, isFalse);
      expect(resTwo.errors.join(' '), contains('Ütközőbak'));
    });

    test('placing bufferStop, crossing, gate, switchY on tram returns blockedByTram', () {
      final g = EditorGrid();
      g.place(EditorPiece.straightH, (col: 4, row: 2));
      g.place(EditorPiece.tramGreen, (col: 4, row: 2));

      for (final piece in const [
        EditorPiece.bufferStop,
        EditorPiece.crossing,
        EditorPiece.gate,
        EditorPiece.switchY,
      ]) {
        expect(
          g.place(piece, (col: 4, row: 2)),
          EditorEditResult.blockedByTram,
          reason: piece.name,
        );
      }
    });
  });

  group('switchY (3-way and 4-way)', () {
    test('3-way switchY spur builds PlatformShape.wye with radius 32', () {
      final g = EditorGrid();
      drawRing(g, 2, 2, 8, 6);
      g.place(EditorPiece.switchY, (col: 8, row: 4));
      g.place(EditorPiece.straightH, (col: 9, row: 4));
      g.place(EditorPiece.bufferStop, (col: 10, row: 4));
      g.place(EditorPiece.tramGreen, (col: 4, row: 2));
      g.place(EditorPiece.tramRed, (col: 4, row: 6));

      final result = builder.build(g);
      expect(result.isValid, isTrue, reason: result.errors.join('; '));
      expect(result.level.crossovers, hasLength(1));
      expect(result.level.crossovers.single.shape, PlatformShape.wye);
      expect(result.level.crossovers.single.radius, 32);
    });

    test('4-way switchY crossing builds PlatformShape.wye with radius 32', () {
      final g = EditorGrid();
      drawRing(g, 2, 2, 8, 6);
      drawRing(g, 6, 4, 12, 8);
      g.place(EditorPiece.switchY, (col: 8, row: 4));
      g.place(EditorPiece.crossing, (col: 6, row: 6));
      g.place(EditorPiece.tramGreen, (col: 4, row: 2));
      g.place(EditorPiece.tramRed, (col: 9, row: 8));

      final result = builder.build(g);
      expect(result.isValid, isTrue, reason: result.errors.join('; '));
      expect(result.level.crossovers, hasLength(1));
      expect(result.level.crossovers.single.shape, PlatformShape.wye);
      expect(result.level.crossovers.single.radius, 32);
    });

    test('switchY with fewer than 3 neighbours fails with Y váltó', () {
      final g = EditorGrid();
      drawRing(g, 2, 2, 8, 6);
      g.place(EditorPiece.switchY, (col: 4, row: 2));
      g.place(EditorPiece.tramGreen, (col: 5, row: 2));
      g.place(EditorPiece.tramRed, (col: 4, row: 6));

      final result = builder.build(g);
      expect(result.isValid, isFalse);
      expect(result.errors.join(' '), contains('Y váltó'));
    });
  });

  test('gate, railIce, railMelted emit valid level entries and JSON/ASCII round-trip', () {
    final g = EditorGrid();
    drawRing(g, 2, 2, 8, 6);
    g.place(EditorPiece.gate, (col: 4, row: 2));
    g.place(EditorPiece.railIce, (col: 5, row: 2));
    g.place(EditorPiece.railMelted, (col: 6, row: 2));
    g.place(EditorPiece.tramGreen, (col: 5, row: 6));
    g.place(EditorPiece.tramRed, (col: 6, row: 6));

    final result = builder.build(g);
    expect(result.isValid, isTrue, reason: result.errors.join('; '));
    expect(result.level.gates, hasLength(1));
    expect(result.level.zones, hasLength(2));
    expect(result.level.zones.map((z) => z.kind).toSet(), {
      TrackZoneKind.ice,
      TrackZoneKind.melted,
    });

    final roundTrip = EditorGrid()
      ..place(EditorPiece.crossing, (col: 0, row: 0))
      ..place(EditorPiece.bufferStop, (col: 1, row: 0))
      ..place(EditorPiece.switchY, (col: 2, row: 0))
      ..place(EditorPiece.gate, (col: 3, row: 0))
      ..place(EditorPiece.railIce, (col: 4, row: 0))
      ..place(EditorPiece.railMelted, (col: 5, row: 0));
    final decoded = EditorGrid.fromJson(roundTrip.toJson());
    expect(decoded.rails, roundTrip.rails);

    final ascii = decoded.toAscii();
    for (final glyph in const ['┼', '▪', '¥', '╫', '≈', '~']) {
      expect(ascii, contains(glyph));
    }
  });
}
