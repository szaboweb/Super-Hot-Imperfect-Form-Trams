import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/editor/editor_piece.dart';

/// Paints a single [EditorPiece] centred inside [size] using pure Canvas.
class EditorPiecePainter extends CustomPainter {
  const EditorPiecePainter({required this.piece, this.dim = false});

  final EditorPiece piece;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) =>
      drawEditorPiece(canvas, size, piece, dim: dim);

  @override
  bool shouldRepaint(covariant EditorPiecePainter old) =>
      old.piece != piece || old.dim != dim;
}

/// Draws [piece] into [canvas] within `Offset.zero & size` (pure Canvas, no assets).
void drawEditorPiece(
  Canvas canvas,
  Size size,
  EditorPiece piece, {
  bool dim = false,
}) {
  final alpha = dim ? 0.45 : 1.0;
  if (piece.isTram) {
    _drawTram(canvas, size, piece == EditorPiece.tramGreen, alpha);
    return;
  }
  if (piece.isSwitch) {
    _drawSwitch(canvas, size, piece, alpha);
    return;
  }
  if (piece == EditorPiece.straightH || piece == EditorPiece.straightV) {
    _drawStraight(canvas, size, piece == EditorPiece.straightH, alpha);
    return;
  }
  _drawCorner(canvas, size, piece, alpha);
}

void _drawStraight(Canvas canvas, Size size, bool horizontal, double alpha) {
  final w = size.width;
  final h = size.height;
  final sleeperPaint = Paint()
    ..color = const Color(0xFF5D4B3B).withValues(alpha: alpha)
    ..strokeWidth = math.max(2, math.min(w, h) * 0.06);
  final railPaint = Paint()
    ..color = const Color(0xFFD0D6DE).withValues(alpha: alpha)
    ..strokeWidth = math.max(1.5, math.min(w, h) * 0.05)
    ..strokeCap = StrokeCap.butt;

  final gauge = (horizontal ? h : w) * 0.16;
  const sleepers = 4;
  for (var i = 0; i < sleepers; i++) {
    final t = (i + 0.5) / sleepers;
    if (horizontal) {
      final x = w * t;
      canvas.drawLine(
        Offset(x, h * 0.5 - gauge * 1.6),
        Offset(x, h * 0.5 + gauge * 1.6),
        sleeperPaint,
      );
    } else {
      final y = h * t;
      canvas.drawLine(
        Offset(w * 0.5 - gauge * 1.6, y),
        Offset(w * 0.5 + gauge * 1.6, y),
        sleeperPaint,
      );
    }
  }
  if (horizontal) {
    canvas.drawLine(
      Offset(0, h * 0.5 - gauge),
      Offset(w, h * 0.5 - gauge),
      railPaint,
    );
    canvas.drawLine(
      Offset(0, h * 0.5 + gauge),
      Offset(w, h * 0.5 + gauge),
      railPaint,
    );
  } else {
    canvas.drawLine(
      Offset(w * 0.5 - gauge, 0),
      Offset(w * 0.5 - gauge, h),
      railPaint,
    );
    canvas.drawLine(
      Offset(w * 0.5 + gauge, 0),
      Offset(w * 0.5 + gauge, h),
      railPaint,
    );
  }
}

void _drawCorner(Canvas canvas, Size size, EditorPiece piece, double alpha) {
  final w = size.width;
  final h = size.height;
  final r = math.min(w, h) * 0.5;
  final gauge = r * 0.32;

  final pivot = switch (piece) {
    EditorPiece.cornerNE => Offset(w, 0),
    EditorPiece.cornerNW => Offset.zero,
    EditorPiece.cornerSE => Offset(w, h),
    EditorPiece.cornerSW => Offset(0, h),
    _ => Offset.zero,
  };
  final startAngle = switch (piece) {
    EditorPiece.cornerNE => math.pi * 0.5,
    EditorPiece.cornerNW => 0.0,
    EditorPiece.cornerSE => math.pi,
    EditorPiece.cornerSW => math.pi * 1.5,
    _ => 0.0,
  };

  final sleeperPaint = Paint()
    ..color = const Color(0xFF5D4B3B).withValues(alpha: alpha)
    ..strokeWidth = math.max(2, r * 0.12);
  for (var i = 1; i <= 3; i++) {
    final a = startAngle + (math.pi * 0.5) * (i / 4);
    final dir = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(
      pivot + dir * (r - gauge * 1.6),
      pivot + dir * (r + gauge * 1.6),
      sleeperPaint,
    );
  }

  final railPaint = Paint()
    ..color = const Color(0xFFD0D6DE).withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.5, r * 0.1);
  for (final radius in [r - gauge, r + gauge]) {
    final rect = Rect.fromCircle(center: pivot, radius: radius);
    canvas.drawArc(rect, startAngle, math.pi * 0.5, false, railPaint);
  }
}

void _drawSwitch(Canvas canvas, Size size, EditorPiece piece, double alpha) {
  final center = Offset(size.width * 0.5, size.height * 0.5);
  final radius = math.min(size.width, size.height) * 0.4;
  final fill = Paint()
    ..color = const Color(0xFF334155).withValues(alpha: alpha);
  final border = Paint()
    ..color = const Color(0xFF94A3B8).withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  if (piece == EditorPiece.switchCircle) {
    canvas.drawCircle(center, radius, fill);
    canvas.drawCircle(center, radius, border);
    _drawStraight(canvas, size, true, alpha);
    _drawStraight(canvas, size, false, alpha);
    return;
  }
  if (piece == EditorPiece.switchRectangle) {
    final rect = Rect.fromCenter(
      center: center,
      width: radius * 1.9,
      height: radius * 1.35,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rrect, fill);
    canvas.drawRRect(rrect, border);
    _drawStraight(canvas, size, true, alpha);
    return;
  }
  // switchTriangle
  final path = Path()
    ..moveTo(center.dx, center.dy - radius)
    ..lineTo(center.dx + radius * 0.95, center.dy + radius * 0.8)
    ..lineTo(center.dx - radius * 0.95, center.dy + radius * 0.8)
    ..close();
  canvas.drawPath(path, fill);
  canvas.drawPath(path, border);
  _drawStraight(canvas, size, true, alpha);
  _drawStraight(canvas, size, false, alpha);
}

void _drawTram(Canvas canvas, Size size, bool isGreen, double alpha) {
  final center = Offset(size.width * 0.5, size.height * 0.5);
  final bodyW = size.width * 0.62;
  final bodyH = size.height * 0.38;
  final baseColor = isGreen ? const Color(0xFF4CAF50) : const Color(0xFFE4572E);
  final body = RRect.fromRectAndRadius(
    Rect.fromCenter(center: center, width: bodyW, height: bodyH),
    const Radius.circular(5),
  );
  canvas.drawRRect(body, Paint()..color = baseColor.withValues(alpha: alpha));
  canvas.drawRRect(
    body,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.85 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6,
  );
  // Roof stripe & front cab indicator
  final roof = Rect.fromCenter(
    center: center,
    width: bodyW * 0.55,
    height: bodyH * 0.48,
  );
  canvas.drawRect(
    roof,
    Paint()..color = Colors.black.withValues(alpha: 0.28 * alpha),
  );
  final cab = Rect.fromCenter(
    center: Offset(center.dx + bodyW * 0.34, center.dy),
    width: bodyW * 0.14,
    height: bodyH * 0.62,
  );
  canvas.drawRect(
    cab,
    Paint()..color = const Color(0xFFFEF08A).withValues(alpha: 0.9 * alpha),
  );
}
