import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show FontWeight, TextStyle;

import '../systems/track_path.dart';
import 'tram_component.dart';

/// Layer 7 (HUD): screen-space overlay added to the camera viewport.
/// Speedometer, brake-heat bar, SHIFT switch hint and mini-map (placeholders).
class HudComponent extends PositionComponent {
  HudComponent({required this.tram, required this.paths});

  final TramComponent tram;
  final List<TrackPath> paths;

  static const double mapWidth = 150;
  static const double mapHeight = 96;
  static const double margin = 16;

  late final Rect _worldBox;
  late final double _mapScale;
  late final Path _mapTrack;

  final TextPaint _big = TextPaint(
    style: const TextStyle(
      color: Color(0xFFF3E9D2),
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
  );
  final TextPaint _small = TextPaint(
    style: const TextStyle(color: Color(0xFFB8BCC8), fontSize: 13),
  );

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  Future<void> onLoad() async {
    var box = Rect.fromLTRB(
      paths.first.points.first.x,
      paths.first.points.first.y,
      paths.first.points.first.x,
      paths.first.points.first.y,
    );
    for (final path in paths) {
      for (final p in path.points) {
        box = box.expandToInclude(Rect.fromLTWH(p.x, p.y, 0, 0));
      }
    }
    _worldBox = box;
    _mapScale = math.min(
      (mapWidth - 12) / box.width,
      (mapHeight - 12) / box.height,
    );
    _mapTrack = Path();
    for (final path in paths) {
      for (var i = 0; i < path.points.length; i++) {
        final m = _toMap(path.points[i].x, path.points[i].y);
        if (i == 0) {
          _mapTrack.moveTo(m.dx, m.dy);
        } else {
          _mapTrack.lineTo(m.dx, m.dy);
        }
      }
    }
  }

  Offset _toMap(double x, double y) => Offset(
    mapWidth / 2 + (x - _worldBox.center.dx) * _mapScale,
    mapHeight / 2 + (y - _worldBox.center.dy) * _mapScale,
  );

  @override
  void render(Canvas canvas) {
    // Placeholder unit conversion: px/s to "km/h".
    final kmh = (tram.speed.abs() * 0.3).round();
    _big.render(canvas, '$kmh km/h', Vector2(margin, margin));

    _small.render(canvas, 'BRAKE', Vector2(margin, margin + 40));
    const barRect = Rect.fromLTWH(margin + 52, margin + 43, 140, 10);
    canvas
      ..drawRect(barRect, Paint()..color = const Color(0x66000000))
      ..drawRect(
        Rect.fromLTWH(
          barRect.left,
          barRect.top,
          barRect.width * tram.brakeHeat,
          barRect.height,
        ),
        Paint()
          ..color = Color.lerp(
            const Color(0xFF3DDC84),
            const Color(0xFFE5483B),
            tram.brakeHeat,
          )!,
      );

    _small.render(canvas, '[SHIFT] flip switch', Vector2(margin, size.y - 30));

    final mapOrigin = Offset(size.x - mapWidth - margin, margin);
    canvas
      ..save()
      ..translate(mapOrigin.dx, mapOrigin.dy)
      ..drawRect(
        const Rect.fromLTWH(0, 0, mapWidth, mapHeight),
        Paint()..color = const Color(0x88000000),
      )
      ..drawPath(
        _mapTrack,
        Paint()
          ..color = const Color(0xFFC9CED6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      )
      ..drawCircle(
        _toMap(tram.position.x, tram.position.y),
        3.5,
        Paint()..color = const Color(0xFFE4572E),
      )
      ..restore();
  }
}
