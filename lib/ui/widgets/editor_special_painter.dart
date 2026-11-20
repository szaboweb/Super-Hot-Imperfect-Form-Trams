import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/editor/editor_piece.dart';
import 'editor_piece_painter.dart';
import 'editor_switch_painter.dart';

/// Draws special track pieces (crossing, buffer stop, gate, rail zones).
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
    default:
      if (piece.isTSwitch) {
        drawEditorSwitchT(canvas, size, piece.tStemSide ?? wyeStemSide, alpha);
      } else if (piece.isYSwitch) {
        drawEditorSwitchYTurnout(canvas, size, piece, alpha);
      }
  }
}

void _drawCrossing(Canvas canvas, Size size, double alpha) {
  drawStraightEditorRail(canvas, size, true, alpha);
  drawStraightEditorRail(canvas, size, false, alpha);
  final u = math.min(size.width, size.height);
  final c = Offset(size.width * 0.5, size.height * 0.5);
  final g = u * 0.16;
  final gap = editorFillPaint(0xFF0F172A, 0.78 * alpha);
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
  canvas.drawPath(diamond, editorFillPaint(0xFF1E293B, 0.9 * alpha));
  canvas.drawPath(diamond, editorStrokePaint(0xFF64748B, 1.2, 0.85 * alpha));
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
  drawRotatedEditor(canvas, size, angle, () {
    final sleeper = editorStrokePaint(0xFF5D4B3B, math.max(2, u * 0.06), alpha);
    for (final x in [-span * 0.34, -span * 0.14]) {
      canvas.drawLine(Offset(x, -g * 1.6), Offset(x, g * 1.6), sleeper);
    }
    final rail = editorStrokePaint(0xFFD0D6DE, math.max(1.5, u * 0.05), alpha);
    final strut = editorStrokePaint(0xFF94A3B8, math.max(1.5, u * 0.05), alpha);
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
    canvas.drawRect(beam, editorFillPaint(0xFFE5483B, alpha));
    final cream = Rect.fromCenter(
      center: beam.center,
      width: beam.width,
      height: g * 1.15,
    );
    canvas.drawRect(cream, editorFillPaint(0xFFF3E9D2, alpha));
  });
}

void _drawGate(Canvas canvas, Size size, bool isVertical, double alpha) {
  drawStraightEditorRail(canvas, size, !isVertical, alpha);
  final u = math.min(size.width, size.height);
  drawRotatedEditor(canvas, size, isVertical ? math.pi * 0.5 : 0, () {
    final post = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, -u * 0.34),
        width: u * 0.2,
        height: u * 0.16,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(post, editorFillPaint(0xFF1E293B, alpha));
    canvas.drawRRect(post, editorStrokePaint(0xFF94A3B8, 1.3, alpha));
    final arm = Rect.fromLTRB(-u * 0.045, -u * 0.25, u * 0.045, u * 0.36);
    canvas.drawRect(arm, editorFillPaint(0xFFEF4444, alpha));
    canvas.save();
    canvas.clipRect(arm);
    final stripe = editorStrokePaint(0xFFF8FAFC, u * 0.045, alpha);
    for (var y = -u * 0.24; y <= u * 0.38; y += u * 0.14) {
      canvas.drawLine(
        Offset(-u * 0.08, y - u * 0.05),
        Offset(u * 0.08, y + u * 0.05),
        stripe,
      );
    }
    canvas.restore();
    for (final sign in const [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(sign * u * 0.045, -u * 0.34),
        u * 0.032,
        editorFillPaint(sign < 0 ? 0xFFEF4444 : 0xFF22C55E, alpha),
      );
    }
  });
}

void _drawIceRail(Canvas canvas, Size size, bool isVertical, double alpha) {
  final u = math.min(size.width, size.height);
  final span = isVertical ? size.height : size.width;
  final angle = isVertical ? math.pi * 0.5 : 0.0;
  drawRotatedEditor(canvas, size, angle, () {
    final bed = Rect.fromCenter(
      center: Offset.zero,
      width: span,
      height: u * 0.58,
    );
    canvas.drawRect(bed, editorFillPaint(0xFF67E8F9, 0.28 * alpha));
  });
  drawStraightEditorRail(canvas, size, !isVertical, alpha);
  drawRotatedEditor(canvas, size, angle, () {
    final frost = editorStrokePaint(0xFFA5F3FC, 1.3, 0.65 * alpha);
    for (final (x1, y1, x2, y2) in const [
      (-0.32, -0.22, -0.18, -0.14),
      (0.16, 0.22, 0.3, 0.14),
    ]) {
      canvas.drawLine(Offset(u * x1, u * y1), Offset(u * x2, u * y2), frost);
    }
    final chev = editorStrokePaint(
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
  drawRotatedEditor(canvas, size, angle, () {
    final bed = Rect.fromCenter(
      center: Offset.zero,
      width: span,
      height: u * 0.6,
    );
    canvas.drawRect(bed, editorFillPaint(0xFF78350F, 0.55 * alpha));
    final puddle = editorFillPaint(0xFFD97706, 0.55 * alpha);
    for (final (ox, oy, pw, ph) in const [
      (-0.18, 0.14, 0.28, 0.14),
      (0.16, -0.14, 0.24, 0.12),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(u * ox, u * oy),
          width: u * pw,
          height: u * ph,
        ),
        puddle,
      );
    }
  });
  drawStraightEditorRail(canvas, size, !isVertical, alpha);
  drawRotatedEditor(canvas, size, angle, () {
    final wave = editorStrokePaint(
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
