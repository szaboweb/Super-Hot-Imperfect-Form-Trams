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
  LevelData get level => LevelData.fromJson(json!);
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
          {
            'id': _segmentId(i),
            'end': 'connected',
            'nextSegment': _segmentId(i),
            'points': [
              for (final p in geometry.ringPoints(rings[i])) [_r(p.x), _r(p.y)],
            ],
          },
      ],
      'props': <Map<String, dynamic>>[],
      'spawns': [
        _spawn(grid, geometry, rings, EditorPiece.tramGreen),
        _spawn(grid, geometry, rings, EditorPiece.tramRed),
      ],
      'goal': {'crashes': 1},
      'crossovers': [for (final c in plan.crossovers) _crossover(c)],
    };
  }

  Map<String, dynamic> _spawn(
    EditorGrid grid,
    EditorGeometry geometry,
    List<EditorRing> rings,
    EditorPiece tram,
  ) {
    final cell = grid.tramCell(tram)!;
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
    final a = _segmentId(c.rings.first);
    final b = _segmentId(c.rings.last);
    final shape = switch (c.piece) {
      EditorPiece.switchRectangle => 'rectangle',
      EditorPiece.switchTriangle => 'triangle',
      _ => 'circle',
    };
    final links = (c.piece == EditorPiece.switchTriangle || a == b)
        ? [
            for (final r in c.rings)
              {'from': _segmentId(r), 'to': _segmentId(r)},
          ]
        : [
            {'from': a, 'to': b},
            {'from': b, 'to': a},
          ];
    return {
      'id': c.id,
      'platformShape': shape,
      'x': _r(c.center.x),
      'y': _r(c.center.y),
      'radius': 48,
      'links': links,
    };
  }

  double _r(double v) => (v * 100).round() / 100;
}
