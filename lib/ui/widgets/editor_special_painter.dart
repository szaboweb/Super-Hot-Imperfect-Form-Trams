import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/editor/editor_piece.dart';
import 'editor_piece_painter.dart';

/// Draws special track pieces (crossing, buffer stop, gate, rail zones, Y-switch).
void drawSpecialEditorPiece(
  Canvas canvas,
  Size size,
  EditorPiece piece,
  double alpha, {
  bool isVertical = false,
  EditorSide bufferSide = EditorSide.west,
  EditorSide? wyeStemSide = EditorSide.south,
}) {
  switch (piece) {
    case EditorPiece.crossing:
      _drawCrossing(canvas, size, alpha);
    case EditorPiece.bufferStop:
      _drawBufferStop(canvas, size, bufferSide, alpha);
    case EditorPiece.gate:
      _drawGate(canvas, size, isVertical, alpha);
    case EditorPiece.railIce:
      _drawIceRail(canvas, size, isVertical, alpha);
    case EditorPiece.railMelted:
      _drawMeltedRail(canvas, size, isVertical, alpha);
    case EditorPiece.switchY:
      _drawSwitchY(canvas, size, wyeStemSide, alpha);
    default:
      break;
  }
}

Paint _fill(int hex, double alpha) =>
    Paint()..color = Color(hex).withValues(alpha: alpha);

Paint _stroke(int hex, double w, double alpha, {bool round = false}) => Paint()
  ..color = Color(hex).withValues(alpha: alpha)
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = round ? StrokeCap.round : StrokeCap.butt;

void _rotated(Canvas canvas, Size size, double angle, VoidCallback draw) {
  canvas.save();
  canvas.translate(size.width * 0.5, size.height * 0.5);
  if (angle != 0) canvas.rotate(angle);
  draw();
  canvas.restore();
}

void _drawCrossing(Canvas canvas, Size size, double alpha) {
  drawStraightEditorRail(canvas, size, true, alpha);
  drawStraightEditorRail(canvas, size, false, alpha);
  final u = math.min(size.width, size.height);
  final c = Offset(size.width * 0.5, size.height * 0.5);
  final g = u * 0.16;
  final gap = _fill(0xFF0F172A, 0.78 * alpha);
  for (final sx in const [-1.0, 1.0]) {
    for (final sy in const [-1.0, 1.0]) {
      canvas.drawCircle(Offset(c.dx + sx * g, c.dy + sy * g), u * 0.035, gap);
    }
  }
  final r = g * 0.82;
  final diamond = Path()
    ..moveTo(c.dx, c.dy - r)
    ..lineTo(c.dx + r, c.dy)
    ..lineTo(c.dx, c.dy + r)
    ..lineTo(c.dx - r, c.dy)
    ..close();
  canvas.drawPath(diamond, _fill(0xFF1E293B, 0.9 * alpha));
  canvas.drawPath(diamond, _stroke(0xFF64748B, 1.2, 0.85 * alpha));
}

void _drawBufferStop(Canvas canvas, Size size, EditorSide side, double alpha) {
  final u = math.min(size.width, size.height);
  final span = side.isHorizontal ? size.width : size.height;
  final g = u * 0.16;
  final angle = switch (side) {
    EditorSide.west => 0.0,
    EditorSide.north => math.pi * 0.5,
    EditorSide.east => math.pi,
    EditorSide.south => -math.pi * 0.5,
  };
  _rotated(canvas, size, angle, () {
    final sleeper = _stroke(0xFF5D4B3B, math.max(2, u * 0.06), alpha);
    for (final x in [-span * 0.34, -span * 0.14]) {
      canvas.drawLine(Offset(x, -g * 1.6), Offset(x, g * 1.6), sleeper);
    }
    final rail = _stroke(0xFFD0D6DE, math.max(1.5, u * 0.05), alpha);
    final strut = _stroke(0xFF94A3B8, math.max(1.5, u * 0.05), alpha);
    for (final s in const [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(-span * 0.5, s * g),
        Offset(u * 0.06, s * g),
        rail,
      );
      canvas.drawLine(
        Offset(u * 0.06, s * g),
        Offset(u * 0.25, s * g * 0.6),
        strut,
      );
    }
    final beam = Rect.fromCenter(
      center: Offset(u * 0.06, 0),
      width: math.max(5, u * 0.12),
      height: g * 3.4,
    );
    canvas.drawRect(beam, _fill(0xFFE5483B, alpha));
    final cream = Rect.fromCenter(
      center: beam.center,
      width: beam.width,
      height: g * 1.15,
    );
    canvas.drawRect(cream, _fill(0xFFF3E9D2, alpha));
  });
}

void _drawGate(Canvas canvas, Size size, bool isVertical, double alpha) {
  drawStraightEditorRail(canvas, size, !isVertical, alpha);
  final u = math.min(size.width, size.height);
  _rotated(canvas, size, isVertical ? math.pi * 0.5 : 0, () {
    final post = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, -u * 0.34),
        width: u * 0.2,
        height: u * 0.16,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(post, _fill(0xFF1E293B, alpha));
    canvas.drawRRect(post, _stroke(0xFF94A3B8, 1.3, alpha));
    final arm = Rect.fromLTRB(-u * 0.045, -u * 0.25, u * 0.045, u * 0.36);
    canvas.drawRect(arm, _fill(0xFFEF4444, alpha));
    canvas.save();
    canvas.clipRect(arm);
    final stripe = _stroke(0xFFF8FAFC, u * 0.045, alpha);
    for (var y = -u * 0.24; y <= u * 0.38; y += u * 0.14) {
      canvas.drawLine(
        Offset(-u * 0.08, y - u * 0.05),
        Offset(u * 0.08, y + u * 0.05),
        stripe,
      );
    }
    canvas.restore();
    canvas.drawCircle(
      Offset(-u * 0.045, -u * 0.34),
      u * 0.032,
      _fill(0xFFEF4444, alpha),
    );
    canvas.drawCircle(
      Offset(u * 0.045, -u * 0.34),
      u * 0.032,
      _fill(0xFF22C55E, alpha),
    );
  });
}

void _drawIceRail(Canvas canvas, Size size, bool isVertical, double alpha) {
  final u = math.min(size.width, size.height);
  final span = isVertical ? size.height : size.width;
  final angle = isVertical ? math.pi * 0.5 : 0.0;
  _rotated(canvas, size, angle, () {
    final bed = Rect.fromCenter(
      center: Offset.zero,
      width: span,
      height: u * 0.58,
    );
    canvas.drawRect(bed, _fill(0xFF67E8F9, 0.28 * alpha));
  });
  drawStraightEditorRail(canvas, size, !isVertical, alpha);
  _rotated(canvas, size, angle, () {
    final frost = _stroke(0xFFA5F3FC, 1.3, 0.65 * alpha);
    canvas.drawLine(
      Offset(-u * 0.32, -u * 0.22),
      Offset(-u * 0.18, -u * 0.14),
      frost,
    );
    canvas.drawLine(
      Offset(u * 0.16, u * 0.22),
      Offset(u * 0.3, u * 0.14),
      frost,
    );
    final chev = _stroke(
      0xFFCFFAFE,
      math.max(1.6, u * 0.045),
      0.9 * alpha,
      round: true,
    );
    for (final dx in [-u * 0.12, u * 0.06]) {
      final p = Path()
        ..moveTo(dx - u * 0.06, -u * 0.08)
        ..lineTo(dx + u * 0.03, 0)
        ..lineTo(dx - u * 0.06, u * 0.08);
      canvas.drawPath(p, chev);
    }
  });
}

void _drawMeltedRail(Canvas canvas, Size size, bool isVertical, double alpha) {
  final u = math.min(size.width, size.height);
  final span = isVertical ? size.height : size.width;
  final angle = isVertical ? math.pi * 0.5 : 0.0;
  _rotated(canvas, size, angle, () {
    final bed = Rect.fromCenter(
      center: Offset.zero,
      width: span,
      height: u * 0.6,
    );
    canvas.drawRect(bed, _fill(0xFF78350F, 0.55 * alpha));
    final puddle = _fill(0xFFD97706, 0.55 * alpha);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-u * 0.18, u * 0.14),
        width: u * 0.28,
        height: u * 0.14,
      ),
      puddle,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(u * 0.16, -u * 0.14),
        width: u * 0.24,
        height: u * 0.12,
      ),
      puddle,
    );
  });
  drawStraightEditorRail(canvas, size, !isVertical, alpha);
  _rotated(canvas, size, angle, () {
    final wave = _stroke(
      0xFFFBBF24,
      math.max(1.6, u * 0.045),
      0.9 * alpha,
      round: true,
    );
    final p = Path()
      ..moveTo(-u * 0.2, 0)
      ..quadraticBezierTo(-u * 0.1, -u * 0.09, 0, 0)
      ..quadraticBezierTo(u * 0.1, u * 0.09, u * 0.2, 0);
    canvas.drawPath(p, wave);
  });
}

void _drawSwitchY(
  Canvas canvas,
  Size size,
  EditorSide? stemSide,
  double alpha,
) {
  final u = math.min(size.width, size.height);
  final c = Offset(size.width * 0.5, size.height * 0.5);
  final h = u * 0.42;
  final cut = u * 0.14;
  final bed = Path()
    ..moveTo(c.dx - h + cut, c.dy - h)
    ..lineTo(c.dx + h - cut, c.dy - h)
    ..lineTo(c.dx + h, c.dy - h + cut)
    ..lineTo(c.dx + h, c.dy + h - cut)
    ..lineTo(c.dx + h - cut, c.dy + h)
    ..lineTo(c.dx - h + cut, c.dy + h)
    ..lineTo(c.dx - h, c.dy + h - cut)
    ..lineTo(c.dx - h, c.dy - h + cut)
    ..close();
  canvas.drawPath(bed, _fill(0xFF334155, alpha));
  canvas.drawPath(bed, _stroke(0xFF60A5FA, 1.8, alpha));
  if (stemSide == null || !stemSide.isHorizontal) {
    drawStraightEditorRail(canvas, size, true, alpha);
  }
  if (stemSide == null || stemSide.isHorizontal) {
    drawStraightEditorRail(canvas, size, false, alpha);
  }
  final corners = switch (stemSide) {
    EditorSide.north => const [EditorPiece.cornerNW, EditorPiece.cornerNE],
    EditorSide.south => const [EditorPiece.cornerSW, EditorPiece.cornerSE],
    EditorSide.east => const [EditorPiece.cornerNE, EditorPiece.cornerSE],
    EditorSide.west => const [EditorPiece.cornerNW, EditorPiece.cornerSW],
    null => const [
      EditorPiece.cornerNE,
      EditorPiece.cornerNW,
      EditorPiece.cornerSE,
      EditorPiece.cornerSW,
    ],
  };
  for (final corner in corners) {
    drawCornerEditorRail(canvas, size, corner, alpha, drawSleepers: false);
  }
}
