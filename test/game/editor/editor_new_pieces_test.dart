import 'dart:math' as math;

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

    test('placing bufferStop, crossing, gate, T/Y switches on tram returns blockedByTram', () {
      final g = EditorGrid();
      g.place(EditorPiece.straightH, (col: 4, row: 2));
      g.place(EditorPiece.tramGreen, (col: 4, row: 2));

      for (final piece in const [
        EditorPiece.bufferStop,
        EditorPiece.crossing,
        EditorPiece.gate,
        EditorPiece.switchTNorth,
        EditorPiece.switchTSouth,
        EditorPiece.switchTEast,
        EditorPiece.switchTWest,
        EditorPiece.switchYNorthLeft,
        EditorPiece.switchYEastRight,
      ]) {
        expect(
          g.place(piece, (col: 4, row: 2)),
          EditorEditResult.blockedByTram,
          reason: piece.name,
        );
      }
    });
  });

  group('T-switches (4 orientations)', () {
    test(
      'all 4 T-switch orientations build PlatformShape.wye with radius 32',
      () {
        final cases = [
          (
            piece: EditorPiece.switchTNorth,
            tCell: (col: 5, row: 6),
            spurRail: EditorPiece.straightV,
            spurCell: (col: 5, row: 5),
            bufCell: (col: 5, row: 4),
          ),
          (
            piece: EditorPiece.switchTSouth,
            tCell: (col: 5, row: 2),
            spurRail: EditorPiece.straightV,
            spurCell: (col: 5, row: 3),
            bufCell: (col: 5, row: 4),
          ),
          (
            piece: EditorPiece.switchTEast,
            tCell: (col: 8, row: 4),
            spurRail: EditorPiece.straightH,
            spurCell: (col: 9, row: 4),
            bufCell: (col: 10, row: 4),
          ),
          (
            piece: EditorPiece.switchTWest,
            tCell: (col: 2, row: 4),
            spurRail: EditorPiece.straightH,
            spurCell: (col: 1, row: 4),
            bufCell: (col: 0, row: 4),
          ),
        ];
        for (final c in cases) {
          final g = EditorGrid();
          drawRing(g, 2, 2, 8, 6);
          g.place(c.piece, c.tCell);
          g.place(c.spurRail, c.spurCell);
          g.place(EditorPiece.bufferStop, c.bufCell);
          g.place(EditorPiece.tramGreen, (col: 3, row: 2));
          g.place(EditorPiece.tramRed, (col: 7, row: 6));

          final result = builder.build(g);
          expect(
            result.isValid,
            isTrue,
            reason: '${c.piece.name}: ${result.errors}',
          );
          expect(result.level.crossovers, hasLength(1), reason: c.piece.name);
          expect(result.level.crossovers.single.shape, PlatformShape.wye);
          expect(result.level.crossovers.single.radius, 32);
        }
      },
    );

    test('T-switch missing its stem connection fails with T váltó', () {
      final g = EditorGrid();
      drawRing(g, 2, 2, 8, 6);
      g.place(EditorPiece.switchTNorth, (col: 4, row: 2));
      g.place(EditorPiece.tramGreen, (col: 5, row: 2));
      g.place(EditorPiece.tramRed, (col: 4, row: 6));

      final result = builder.build(g);
      expect(result.isValid, isFalse);
      expect(result.errors.join(' '), contains('T váltó'));
    });

    test('legacy switchY in saved JSON deserializes as switchTSouth', () {
      final decoded = EditorGrid.fromJson({
        'version': 1,
        'cols': 16,
        'rows': 10,
        'tileSize': 64,
        'rails': [
          {'col': 4, 'row': 2, 'piece': 'switchY'},
        ],
        'trams': <String, dynamic>{},
      });
      expect(decoded.railAt((col: 4, row: 2)), EditorPiece.switchTSouth);
    });
  });

  group('Y-switches (8 orientations)', () {
    test(
      'all 8 Y-switch orientations build PlatformShape.turnout with metadata',
      () {
        final cases = [
          (piece: EditorPiece.switchYNorthLeft, cell: (col: 3, row: 4)),
          (piece: EditorPiece.switchYNorthRight, cell: (col: 2, row: 4)),
          (piece: EditorPiece.switchYSouthLeft, cell: (col: 2, row: 4)),
          (piece: EditorPiece.switchYSouthRight, cell: (col: 3, row: 4)),
          (piece: EditorPiece.switchYEastLeft, cell: (col: 6, row: 2)),
          (piece: EditorPiece.switchYEastRight, cell: (col: 6, row: 1)),
          (piece: EditorPiece.switchYWestLeft, cell: (col: 6, row: 1)),
          (piece: EditorPiece.switchYWestRight, cell: (col: 6, row: 2)),
        ];
        for (final c in cases) {
          final g = EditorGrid();
          drawRing(g, 2, 1, 13, 8);
          drawRing(g, 3, 2, 12, 7);
          g.place(c.piece, c.cell);
          g.place(EditorPiece.tramGreen, (col: 9, row: 1));
          g.place(EditorPiece.tramRed, (col: 9, row: 2));

          final result = builder.build(g);
          expect(
            result.isValid,
            isTrue,
            reason: '${c.piece.name}: ${result.errors}',
          );
          final xo = result.level.crossovers.single;
          expect(xo.shape, PlatformShape.turnout, reason: c.piece.name);
          expect(xo.radius, 48, reason: c.piece.name);
          expect(xo.stemPoint, g.cellCenter(c.cell), reason: c.piece.name);
          final fwd = c.piece.yForwardSide!;
          expect(
            xo.forward,
            math.Point<double>(fwd.dCol.toDouble(), fwd.dRow.toDouble()),
            reason: c.piece.name,
          );
        }
      },
    );

    test(
      'Y-switch without parallel lane on branch side fails with Y váltó',
      () {
        final g = EditorGrid();
        drawRing(g, 2, 2, 8, 6);
        g.place(EditorPiece.switchYEastLeft, (col: 5, row: 2));
        g.place(EditorPiece.tramGreen, (col: 6, row: 2));
        g.place(EditorPiece.tramRed, (col: 5, row: 6));

        final result = builder.build(g);
        expect(result.isValid, isFalse);
        expect(result.errors.join(' '), contains('Y váltó'));
      },
    );
  });

  test('gate, railIce, railMelted, T/Y emit valid level entries and JSON/ASCII round-trip', () {
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
      ..place(EditorPiece.switchTNorth, (col: 2, row: 0))
      ..place(EditorPiece.switchYEastRight, (col: 6, row: 0))
      ..place(EditorPiece.gate, (col: 3, row: 0))
      ..place(EditorPiece.railIce, (col: 4, row: 0))
      ..place(EditorPiece.railMelted, (col: 5, row: 0));
    final decoded = EditorGrid.fromJson(roundTrip.toJson());
    expect(decoded.rails, roundTrip.rails);

    final ascii = decoded.toAscii();
    for (final glyph in const ['┼', '▪', 'T', 'Y', '╫', '≈', '~']) {
      expect(ascii, contains(glyph));
    }
  });
}
