import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../graphics/render_layer.dart';
import '../systems/track_path.dart';
import 'track_component.dart';

/// Layer 2 (ground): asphalt with cobble grid, channel gaps (the depth layer
/// shows through), road/bridge decks under the rails and skid marks.
/// Placeholder visuals, Canvas only.
class GroundComponent extends PositionComponent {
  GroundComponent({
    required this.bounds,
    required this.channels,
    required this.paths,
  }) : super(priority: RenderLayer.ground.priority);

  /// Playable area size in world px, centred on the origin.
  final Vector2 bounds;

  /// Rectangles (world px) where there is no ground.
  final List<Rect> channels;

  /// Track centre-lines; a road/bridge deck is laid under each.
  final List<TrackPath> paths;

  static const int maxSkidMarks = 3000;
  static const double deckWidth = 60;

  late final Path _ground;
  late final Path _deck;
  late final Path _grid;

  final Queue<({Offset position, double angle})> _skids = Queue();

  final Paint _groundPaint = Paint()..color = const Color(0xFF3A3D45);
  final Paint _gridPaint = Paint()
    ..color = const Color(0x14000000)
    ..strokeWidth = 1;
  final Paint _deckPaint = Paint()
    ..color = const Color(0xFF474B55)
    ..style = PaintingStyle.stroke
    ..strokeWidth = deckWidth
    ..strokeJoin = StrokeJoin.round;
  final Paint _skidPaint = Paint()
    ..color = const Color(0xCC000000)
    ..strokeWidth = 1.6;

  Rect get _bounds =>
      Rect.fromCenter(center: Offset.zero, width: bounds.x, height: bounds.y);

  @override
  Future<void> onLoad() async {
    final gaps = Path();
    for (final c in channels) {
      gaps.addRect(c);
    }
    _ground = Path.combine(
      PathOperation.difference,
      Path()..addRect(_bounds),
      gaps,
    );

    _grid = Path();
    for (var x = _bounds.left; x <= _bounds.right; x += 32) {
      _grid
        ..moveTo(x, _bounds.top)
        ..lineTo(x, _bounds.bottom);
    }
    for (var y = _bounds.top; y <= _bounds.bottom; y += 32) {
      _grid
        ..moveTo(_bounds.left, y)
        ..lineTo(_bounds.right, y);
    }

    _deck = Path();
    for (final path in paths) {
      final steps = (path.length / 6).ceil();
      for (var i = 0; i <= steps; i++) {
        final p = path.positionAt(math.min(i * 6.0, path.length));
        if (i == 0) {
          _deck.moveTo(p.x, p.y);
        } else {
          _deck.lineTo(p.x, p.y);
        }
      }
    }
  }

  /// Burns a pair of rail-gauge skid dashes into the ground at [position].
  void addSkidMark(Vector2 position, double angle) {
    _skids.add((position: Offset(position.x, position.y), angle: angle));
    if (_skids.length > maxSkidMarks) _skids.removeFirst();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawPath(_ground, _groundPaint);
    canvas
      ..save()
      ..clipPath(_ground)
      ..drawPath(_grid, _gridPaint)
      ..restore();
    canvas.drawPath(_deck, _deckPaint);

    for (final s in _skids) {
      final dx = math.sin(s.angle) * 3;
      final dy = -math.cos(s.angle) * 3;
      final nx = math.cos(s.angle) * TrackComponent.gauge / 2;
      final ny = math.sin(s.angle) * TrackComponent.gauge / 2;
      for (final side in const [-1, 1]) {
        final c = s.position + Offset(nx * side, ny * side);
        canvas.drawLine(c - Offset(dx, dy), c + Offset(dx, dy), _skidPaint);
      }
    }
  }
}
