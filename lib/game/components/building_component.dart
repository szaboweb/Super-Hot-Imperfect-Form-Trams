import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../graphics/render_layer.dart';

/// Layer 5 (canopy): 2.5D building with camera-parallax rooftop, extruded
/// facades, and drop shadow; placed beside tracks so rails stay unobstructed.
class BuildingComponent extends PositionComponent
    with HasGameReference<FlameGame> {
  BuildingComponent({
    required Vector2 position,
    required Vector2 size,
    double angle = 0,
  }) : super(
         position: position,
         size: size,
         angle: angle,
         anchor: Anchor.center,
         priority: RenderLayer.canopy.priority,
       );

  /// Camera-to-building parallax multiplier for the roof offset.
  static const double parallaxFactor = 0.045;

  /// Maximum roof extrusion in px so buildings never spill onto adjacent rails.
  static const double maxRoofShift = 18.0;

  Offset _computeRoofShift() {
    final cam = isMounted ? game.camera.viewfinder.position : Vector2.zero();
    final dx = position.x - cam.x;
    final dy = position.y - cam.y;
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    final localX = dx * cosA + dy * sinA;
    final localY = -dx * sinA + dy * cosA;
    final shift = Offset(
      (localX * parallaxFactor).clamp(-maxRoofShift, maxRoofShift),
      (localY * parallaxFactor).clamp(-maxRoofShift, maxRoofShift),
    );
    return shift.distance < 1.5 ? const Offset(-4, -5) : shift;
  }

  @override
  void render(Canvas canvas) {
    final baseRect = size.toRect();
    final shift = _computeRoofShift();
    final roofRect = baseRect.shift(shift);

    canvas.drawRect(
      baseRect.shift(const Offset(6, 8)),
      Paint()..color = const Color(0x44000000),
    );
    _renderWalls(canvas, baseRect, roofRect, shift);
    _renderRoof(canvas, roofRect);
  }

  void _renderWalls(Canvas canvas, Rect b, Rect r, Offset shift) {
    final faces = [
      if (shift.dy > 0)
        (b.topLeft, b.topRight, r.topRight, r.topLeft, 0xFF545A6A, shift.dy),
      if (shift.dy < 0)
        (
          b.bottomLeft,
          b.bottomRight,
          r.bottomRight,
          r.bottomLeft,
          0xFF282C35,
          -shift.dy,
        ),
      if (shift.dx > 0)
        (
          b.topLeft,
          b.bottomLeft,
          r.bottomLeft,
          r.topLeft,
          0xFF4E5463,
          shift.dx,
        ),
      if (shift.dx < 0)
        (
          b.topRight,
          b.bottomRight,
          r.bottomRight,
          r.topRight,
          0xFF2D313B,
          -shift.dx,
        ),
    ];
    for (final f in faces) {
      _drawWallFace(canvas, f.$1, f.$2, f.$3, f.$4, Color(f.$5), f.$6);
    }
  }

  void _drawWallFace(
    Canvas canvas,
    Offset b0,
    Offset b1,
    Offset r1,
    Offset r0,
    Color wallColor,
    double thickness,
  ) {
    final wall = Path()..addPolygon([b0, b1, r1, r0], true);
    canvas
      ..drawPath(wall, Paint()..color = wallColor)
      ..drawPath(
        wall,
        Paint()
          ..color = const Color(0xFF1F222A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    if (thickness >= 4.0) _drawWallWindows(canvas, b0, b1, r0, r1);
  }

  void _drawWallWindows(
    Canvas canvas,
    Offset b0,
    Offset b1,
    Offset r0,
    Offset r1,
  ) {
    final bays = math.max(1, ((b1 - b0).distance / 20).floor());
    for (var i = 0; i < bays; i++) {
      final pBase0 = Offset.lerp(b0, b1, (i + 0.22) / bays)!;
      final pBase1 = Offset.lerp(b0, b1, (i + 0.78) / bays)!;
      final pRoof0 = Offset.lerp(r0, r1, (i + 0.22) / bays)!;
      final pRoof1 = Offset.lerp(r0, r1, (i + 0.78) / bays)!;
      final pane = Path()
        ..addPolygon([
          Offset.lerp(pBase0, pRoof0, 0.28)!,
          Offset.lerp(pBase1, pRoof1, 0.28)!,
          Offset.lerp(pBase1, pRoof1, 0.74)!,
          Offset.lerp(pBase0, pRoof0, 0.74)!,
        ], true);
      final lit = (i + position.x.toInt().abs()) % 3 == 0;
      canvas.drawPath(
        pane,
        Paint()
          ..color = lit ? const Color(0x99F3D37A) : const Color(0x881B2230),
      );
    }
  }

  void _renderRoof(Canvas canvas, Rect roofRect) {
    final shade = ((position.x * 7 + position.y * 13).abs() % 24).toInt();
    final roof = Color.fromARGB(255, 88 + shade, 92 + shade, 102 + shade);
    final ox = roofRect.left;
    final oy = roofRect.top;
    final unit = Paint()..color = const Color(0xFF9AA0AC);
    final chimney = Paint()..color = const Color(0xFF3B3E47);
    canvas
      ..drawRect(roofRect, Paint()..color = roof)
      ..drawRect(
        roofRect.deflate(5),
        Paint()
          ..color = const Color(0x33000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      )
      ..drawRect(
        roofRect,
        Paint()
          ..color = const Color(0xFF2B2E36)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      )
      ..drawRect(
        Rect.fromLTWH(ox + size.x * 0.15, oy + size.y * 0.2, 16, 12),
        unit,
      )
      ..drawRect(
        Rect.fromLTWH(ox + size.x * 0.55, oy + size.y * 0.55, 16, 12),
        unit,
      )
      ..drawRect(
        Rect.fromLTWH(ox + size.x * 0.75, oy + size.y * 0.15, 8, 8),
        chimney,
      );
  }
}
