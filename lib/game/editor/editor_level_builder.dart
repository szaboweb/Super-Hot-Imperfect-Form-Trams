import '../levels/level_data.dart';
import 'editor_geometry.dart';
import 'editor_grid.dart';
import 'editor_messages.dart';
import 'editor_piece.dart';
import 'editor_switch_planner.dart';
import 'editor_tracer.dart';

/// Result of [EditorLevelBuilder.build]: either [json] (validated) or [issues].
class EditorBuildResult {
  const EditorBuildResult.ok(Map<String, dynamic> this.json)
    : issues = const [];

  const EditorBuildResult.failed(this.issues) : json = null;

  final Map<String, dynamic>? json;
  final List<EditorIssue> issues;

  List<String> get errors => [for (final i in issues) i.message];

  bool get isValid => json != null;

  /// The playable level (only when [isValid]).
  LevelData get level {
    final data = json;
    if (data == null) throw StateError('Cannot build level from failed result');
    return LevelData.fromJson(data);
  }
}

/// Turns an [EditorGrid] into a level JSON map (same keys as
/// assets/data/levels/example_two_loops.json). Pure Dart.
class EditorLevelBuilder {
  const EditorLevelBuilder({this.id = 'editor_level', this.speed = 160});

  final String id;
  final double speed;

  static const int _greenColor = 0xFF4CAF50;
  static const int _redColor = 0xFFE4572E;

  EditorBuildResult build(EditorGrid grid) {
    final issues = _pre(grid);
    if (issues.isNotEmpty) return EditorBuildResult.failed(issues);
    final tracer = EditorTracer(grid);
    final junction = tracer.junctionIssues();
    if (junction.isNotEmpty) return EditorBuildResult.failed(junction);
    final open = tracer.openEnds();
    if (open.isNotEmpty) {
      return EditorBuildResult.failed([
        for (final o in open)
          EditorIssue(EditorMessages.openEnd(o.cell, o.side), cell: o.cell),
      ]);
    }
    final traced = tracer.rings();
    final plan = EditorSwitchPlanner(grid, traced).plan();
    if (plan.issues.isNotEmpty) return EditorBuildResult.failed(plan.issues);
    final rings = [
      for (var i = 0; i < traced.length; i++)
        plan.reversedRings.contains(i) ? traced[i].reversed : traced[i],
    ];
    final json = _json(grid, rings, plan);
    try {
      LevelData.fromJson(json);
    } on FormatException catch (e) {
      return EditorBuildResult.failed([
        EditorIssue(EditorMessages.levelInvalid(e.message)),
      ]);
    }
    return EditorBuildResult.ok(json);
  }

  List<EditorIssue> _pre(EditorGrid grid) => [
    if (grid.rails.isEmpty) const EditorIssue(EditorMessages.emptyGrid),
    for (final t in [EditorPiece.tramGreen, EditorPiece.tramRed])
      if (grid.tramCell(t) == null) EditorIssue(EditorMessages.missingTram(t)),
  ];

  String _segmentId(int ring) => 'loop_${ring + 1}';

  Map<String, dynamic> _json(
    EditorGrid grid,
    List<EditorRing> rings,
    EditorSwitchPlan plan,
  ) {
    final geometry = EditorGeometry(grid);
    return {
      'id': id,
      'city': 'generic_european',
      'tileSize': grid.tileSize,
      'bounds': {'width': grid.worldWidth, 'height': grid.worldHeight},
      'segments': [
        for (var i = 0; i < rings.length; i++)
          _segmentJson(i, rings[i], geometry),
      ],
      'props': <Map<String, dynamic>>[],
      'spawns': [
        _spawn(grid, geometry, rings, EditorPiece.tramGreen),
        _spawn(grid, geometry, rings, EditorPiece.tramRed),
      ],
      'goal': {'crashes': 1},
      'crossovers': [for (final c in plan.crossovers) _crossover(c)],
      'gates': _gatesJson(grid),
      'zones': _zonesJson(grid),
    };
  }

  Map<String, dynamic> _segmentJson(
    int index,
    EditorRing ring,
    EditorGeometry geometry,
  ) => {
    'id': _segmentId(index),
    if (ring.isClosed) ...{
      'end': 'connected',
      'nextSegment': _segmentId(index),
    } else
      'end': 'deadEnd',
    'points': [
      for (final p in geometry.ringPoints(ring)) [_r(p.x), _r(p.y)],
    ],
  };

  List<Map<String, dynamic>> _gatesJson(EditorGrid grid) => [
    for (final e in grid.rails.entries)
      if (e.value == EditorPiece.gate)
        {
          'id': 'gate_${e.key.col}_${e.key.row}',
          'x': _r(grid.cellCenter(e.key).x),
          'y': _r(grid.cellCenter(e.key).y),
        },
  ];

  List<Map<String, dynamic>> _zonesJson(EditorGrid grid) => [
    for (final e in grid.rails.entries)
      if (e.value == EditorPiece.railIce || e.value == EditorPiece.railMelted)
        {
          'kind': e.value == EditorPiece.railIce ? 'ice' : 'melted',
          'x': _r(grid.cellCenter(e.key).x),
          'y': _r(grid.cellCenter(e.key).y),
          'radius': _r(grid.tileSize / 2),
        },
  ];

  Map<String, dynamic> _spawn(
    EditorGrid grid,
    EditorGeometry geometry,
    List<EditorRing> rings,
    EditorPiece tram,
  ) {
    final cell = grid.tramCell(tram);
    if (cell == null) throw StateError('Missing tram cell for $tram');
    for (var i = 0; i < rings.length; i++) {
      final along = geometry.distanceToCellMiddle(rings[i], cell);
      if (along == null) continue;
      return {
        'segment': _segmentId(i),
        'time': 0.0,
        'speed': speed,
        'controls': tram == EditorPiece.tramGreen ? 'wasd' : 'arrows',
        'startDistance': _r(along),
        'color': tram == EditorPiece.tramGreen ? _greenColor : _redColor,
      };
    }
    throw StateError('tram cell $cell is on no ring');
  }

  Map<String, dynamic> _crossover(EditorCrossoverPlan c) {
    final shape = switch (c.piece) {
      EditorPiece.switchRectangle => 'rectangle',
      EditorPiece.switchTriangle => 'triangle',
      _ when c.piece.isTSwitch => 'wye',
      _ when c.piece.isYSwitch => 'turnout',
      _ => 'circle',
    };
    final stem = c.stemCenter;
    final forward = c.forwardSide;
    return {
      'id': c.id,
      'platformShape': shape,
      'x': _r(c.center.x),
      'y': _r(c.center.y),
      'radius': c.radius.round(),
      if (stem != null) 'stemPoint': [_r(stem.x), _r(stem.y)],
      if (forward != null) 'forward': [forward.dCol, forward.dRow],
      'links': _buildCrossoverLinks(c),
    };
  }

  List<Map<String, String>> _buildCrossoverLinks(EditorCrossoverPlan c) {
    final a = _segmentId(c.rings.first);
    final b = _segmentId(c.rings.last);
    if (c.piece.isYSwitch) {
      return [
        {'from': a, 'to': b},
      ];
    }
    if (c.piece == EditorPiece.switchTriangle || a == b) {
      return [
        for (final r in c.rings) {'from': _segmentId(r), 'to': _segmentId(r)},
      ];
    }
    return [
      {'from': a, 'to': b},
      {'from': b, 'to': a},
    ];
  }

  double _r(double v) => (v * 100).round() / 100;
}
