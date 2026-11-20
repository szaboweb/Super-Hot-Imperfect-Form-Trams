import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/editor/editor_piece.dart';
import 'editor_special_painter.dart';

/// Paints a single [EditorPiece] centred inside [size] using pure Canvas.
class EditorPiecePainter extends CustomPainter {
  /// Creates a Canvas painter for an editor palette or grid [piece].
  const EditorPiecePainter({
    required this.piece,
    this.dim = false,
    this.verticalRectangle = false,
    this.verticalInline = false,
    this.bufferSide = EditorSide.west,
    this.wyeStemSide = EditorSide.south,
  });

  /// Piece kind to render.
  final EditorPiece piece;

  /// Whether to render dimmed (e.g., ghosted piece under drag).
  final bool dim;

  /// Legacy orientation flag for vertical rectangle switches.
  final bool verticalRectangle;

  /// Orientation flag for vertical auto-oriented inline rails.
  final bool verticalInline;

  /// Edge from which a spur enters a buffer stop.
  final EditorSide bufferSide;

  /// Stem edge for a Y-switch (`null` renders a 4-way wye junction).
  final EditorSide? wyeStemSide;

  @override
  void paint(Canvas canvas, Size size) => drawEditorPiece(
    canvas,
    size,
    piece,
    dim: dim,
    verticalRectangle: verticalRectangle,
    verticalInline: verticalInline,
    bufferSide: bufferSide,
    wyeStemSide: wyeStemSide,
  );

  @override
  bool shouldRepaint(covariant EditorPiecePainter old) =>
      old.piece != piece ||
      old.dim != dim ||
      old.verticalRectangle != verticalRectangle ||
      old.verticalInline != verticalInline ||
      old.bufferSide != bufferSide ||
      old.wyeStemSide != wyeStemSide;
}

/// Draws [piece] into [canvas] within `Offset.zero & size` (pure Canvas, no assets).
void drawEditorPiece(
  Canvas canvas,
  Size size,
  EditorPiece piece, {
  bool dim = false,
  bool verticalRectangle = false,
  bool verticalInline = false,
  EditorSide bufferSide = EditorSide.west,
  EditorSide? wyeStemSide = EditorSide.south,
}) {
  final alpha = dim ? 0.45 : 1.0;
  final isVertical = verticalInline || verticalRectangle;
  if (piece.isTram) {
    _drawTram(canvas, size, piece == EditorPiece.tramGreen, alpha);
    return;
  }
  if (_isSpecialPiece(piece)) {
    drawSpecialEditorPiece(
      canvas,
      size,
      piece,
      alpha,
      isVertical: isVertical,
      bufferSide: bufferSide,
      wyeStemSide: wyeStemSide,
    );
    return;
  }
  if (piece.isSwitch) {
    _drawSwitch(canvas, size, piece, alpha, isVertical: isVertical);
    return;
  }
  if (piece == EditorPiece.straightH || piece == EditorPiece.straightV) {
    drawStraightEditorRail(canvas, size, piece == EditorPiece.straightH, alpha);
    return;
  }
  drawCornerEditorRail(canvas, size, piece, alpha);
}

bool _isSpecialPiece(EditorPiece piece) =>
    piece == EditorPiece.crossing ||
    piece == EditorPiece.bufferStop ||
    piece == EditorPiece.gate ||
    piece == EditorPiece.railIce ||
    piece == EditorPiece.railMelted ||
    piece.isTSwitch ||
    piece.isYSwitch;

/// Draws sleepers and twin steel rails across [size] in [horizontal] or vertical orientation.
void drawStraightEditorRail(
  Canvas canvas,
  Size size,
  bool horizontal,
  double alpha,
) {
  final w = size.width;
  final h = size.height;
  final u = math.min(w, h);
  final sleeper = Paint()
    ..color = const Color(0xFF5D4B3B).withValues(alpha: alpha)
    ..strokeWidth = math.max(2, u * 0.06);
  final rail = Paint()
    ..color = const Color(0xFFD0D6DE).withValues(alpha: alpha)
    ..strokeWidth = math.max(1.5, u * 0.05);
  final g = (horizontal ? h : w) * 0.16;
  for (var i = 0; i < 4; i++) {
    final t = (i + 0.5) / 4;
    final p1 = horizontal
        ? Offset(w * t, h * 0.5 - g * 1.6)
        : Offset(w * 0.5 - g * 1.6, h * t);
    final p2 = horizontal
        ? Offset(w * t, h * 0.5 + g * 1.6)
        : Offset(w * 0.5 + g * 1.6, h * t);
    canvas.drawLine(p1, p2, sleeper);
  }
  for (final s in const [-1.0, 1.0]) {
    final p1 = horizontal
        ? Offset(0, h * 0.5 + s * g)
        : Offset(w * 0.5 + s * g, 0);
    final p2 = horizontal
        ? Offset(w, h * 0.5 + s * g)
        : Offset(w * 0.5 + s * g, h);
    canvas.drawLine(p1, p2, rail);
  }
}

/// Draws a 90-degree corner rail [piece] with optional sleepers.
void drawCornerEditorRail(
  Canvas canvas,
  Size size,
  EditorPiece piece,
  double alpha, {
  bool drawSleepers = true,
}) {
  final cx = size.width * 0.5;
  final cy = size.height * 0.5;
  final r = math.min(size.width, size.height) * 0.5;
  final g = r * 0.32;
  final (pivot, startAngle) = switch (piece) {
    EditorPiece.cornerNE => (Offset(cx + r, cy - r), math.pi * 0.5),
    EditorPiece.cornerNW => (Offset(cx - r, cy - r), 0.0),
    EditorPiece.cornerSE => (Offset(cx + r, cy + r), math.pi),
    EditorPiece.cornerSW => (Offset(cx - r, cy + r), math.pi * 1.5),
    _ => (Offset(cx - r, cy - r), 0.0),
  };
  if (drawSleepers) _drawCornerSleepers(canvas, pivot, r, g, startAngle, alpha);
  final rail = Paint()
    ..color = const Color(0xFFD0D6DE).withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.5, r * 0.1);
  for (final rad in [r - g, r + g]) {
    canvas.drawArc(
      Rect.fromCircle(center: pivot, radius: rad),
      startAngle,
      math.pi * 0.5,
      false,
      rail,
    );
  }
}

void _drawCornerSleepers(
  Canvas canvas,
  Offset pivot,
  double r,
  double g,
  double startAngle,
  double alpha,
) {
  final sleeper = Paint()
    ..color = const Color(0xFF5D4B3B).withValues(alpha: alpha)
    ..strokeWidth = math.max(2, r * 0.12);
  for (var i = 1; i <= 3; i++) {
    final a = startAngle + (math.pi * 0.5) * (i / 4);
    final dir = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(
      pivot + dir * (r - g * 1.6),
      pivot + dir * (r + g * 1.6),
      sleeper,
    );
  }
}

void _drawSwitch(
  Canvas canvas,
  Size size,
  EditorPiece piece,
  double alpha, {
  bool isVertical = false,
}) {
  final c = Offset(size.width * 0.5, size.height * 0.5);
  final u = math.min(size.width, size.height);
  final r = u * 0.4;
  final fill = Paint()
    ..color = const Color(0xFF334155).withValues(alpha: alpha);
  final border = Paint()
    ..color = const Color(0xFF94A3B8).withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  if (piece == EditorPiece.switchRectangle) {
    final rect = isVertical
        ? Rect.fromCenter(center: c, width: u * 0.42, height: u * 0.68)
        : Rect.fromCenter(center: c, width: r * 1.9, height: r * 1.35);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rrect, fill);
    canvas.drawRRect(rrect, border);
    drawStraightEditorRail(canvas, size, !isVertical, alpha);
    return;
  }
  if (piece == EditorPiece.switchCircle) {
    canvas.drawCircle(c, r, fill);
    canvas.drawCircle(c, r, border);
  } else {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.95, c.dy + r * 0.8)
      ..lineTo(c.dx - r * 0.95, c.dy + r * 0.8)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }
  drawStraightEditorRail(canvas, size, true, alpha);
  drawStraightEditorRail(canvas, size, false, alpha);
}

void _drawTram(Canvas canvas, Size size, bool isGreen, double alpha) {
  final c = Offset(size.width * 0.5, size.height * 0.5);
  final bw = size.width * 0.62;
  final bh = size.height * 0.38;
  final base = isGreen ? const Color(0xFF4CAF50) : const Color(0xFFE4572E);
  final body = RRect.fromRectAndRadius(
    Rect.fromCenter(center: c, width: bw, height: bh),
    const Radius.circular(5),
  );
  canvas.drawRRect(body, Paint()..color = base.withValues(alpha: alpha));
  canvas.drawRRect(
    body,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.85 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6,
  );
  canvas.drawRect(
    Rect.fromCenter(center: c, width: bw * 0.55, height: bh * 0.48),
    Paint()..color = Colors.black.withValues(alpha: 0.28 * alpha),
  );
  canvas.drawRect(
    Rect.fromCenter(
      center: Offset(c.dx + bw * 0.34, c.dy),
      width: bw * 0.14,
      height: bh * 0.62,
    ),
    Paint()..color = const Color(0xFFFEF08A).withValues(alpha: 0.9 * alpha),
  );
}
