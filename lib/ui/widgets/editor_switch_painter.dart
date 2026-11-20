import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/editor/editor_piece.dart';
import 'editor_piece_painter.dart';

/// Returns a solid fill [Paint] for [hex] colour with [alpha] opacity.
Paint editorFillPaint(int hex, double alpha) =>
    Paint()..color = Color(hex).withValues(alpha: alpha);

/// Returns a stroke [Paint] for [hex] colour, [width], and [alpha] opacity.
Paint editorStrokePaint(
  int hex,
  double width,
  double alpha, {
  bool round = false,
}) => Paint()
  ..color = Color(hex).withValues(alpha: alpha)
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = round ? StrokeCap.round : StrokeCap.butt;

/// Runs [draw] with [canvas] translated to the centre of [size] and rotated by [angle] rad.
void drawRotatedEditor(
  Canvas canvas,
  Size size,
  double angle,
  VoidCallback draw,
) {
  canvas.save();
  canvas.translate(size.width * 0.5, size.height * 0.5);
  if (angle != 0) canvas.rotate(angle);
  draw();
  canvas.restore();
}

/// Draws a 3-way or 4-way T-junction switch piece inside [size].
void drawEditorSwitchT(
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
  canvas.drawPath(bed, editorFillPaint(0xFF334155, alpha));
  canvas.drawPath(bed, editorStrokePaint(0xFF60A5FA, 1.8, alpha));
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

/// Draws a diverging Y-switch turnout [piece] inside [size].
void drawEditorSwitchYTurnout(
  Canvas canvas,
  Size size,
  EditorPiece piece,
  double alpha,
) {
  final fwd = piece.yForwardSide;
  final branch = piece.yBranchSide;
  if (fwd == null || branch == null) return;
  final u = math.min(size.width, size.height);
  final c = Offset(size.width * 0.5, size.height * 0.5);
  final bed = RRect.fromRectAndRadius(
    Rect.fromCenter(center: c, width: u * 0.84, height: u * 0.84),
    Radius.circular(u * 0.16),
  );
  canvas.drawRRect(bed, editorFillPaint(0xFF334155, alpha));
  canvas.drawRRect(bed, editorStrokePaint(0xFF38BDF8, 1.8, alpha));
  drawStraightEditorRail(canvas, size, fwd.isHorizontal, alpha);
  final rot = fwd.index * math.pi * 0.5;
  final dir = (fwd.dCol * branch.dRow - fwd.dRow * branch.dCol) >= 0
      ? 1.0
      : -1.0;
  final w = math.max(1.5, u * 0.055);
  final branchPaint = editorStrokePaint(0xFF93C5FD, w, alpha, round: true);
  final arrowPaint = editorStrokePaint(0xFFFFB627, w, alpha, round: true);
  drawRotatedEditor(canvas, size, rot, () {
    for (final dx in [-u * 0.12, u * 0.12]) {
      final p = Path()
        ..moveTo(dx, u * 0.34)
        ..cubicTo(
          dx,
          u * 0.05,
          dir * u * 0.24 + dx * 0.5,
          -u * 0.05,
          dir * u * 0.46,
          -u * 0.34 + dx * 0.3,
        );
      canvas.drawPath(p, branchPaint);
    }
    final arrow = Path()
      ..moveTo(-u * 0.1, -u * 0.06)
      ..lineTo(0, -u * 0.22)
      ..lineTo(u * 0.1, -u * 0.06);
    canvas.drawPath(arrow, arrowPaint);
  });
}
