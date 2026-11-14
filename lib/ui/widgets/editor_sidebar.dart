import 'package:flutter/material.dart';

import '../../game/editor/editor_controller.dart';
import '../../game/editor/editor_grid.dart';
import '../../game/editor/editor_piece.dart';
import 'editor_piece_painter.dart';

/// Drag payload carried either from a sidebar shelf or from an existing grid cell.
class EditorDragPayload {
  const EditorDragPayload.fromShelf(this.piece) : fromCell = null;
  const EditorDragPayload.fromGrid(this.piece, EditorCell this.fromCell);

  final EditorPiece piece;
  final EditorCell? fromCell;
}

/// Left sidebar containing the three piece shelves: Sínek, Váltók, Villamosok.
class EditorSidebar extends StatelessWidget {
  const EditorSidebar({super.key, required this.controller});

  final EditorController controller;

  static const _railPieces = [
    (EditorPiece.straightH, 'Vízszintes'),
    (EditorPiece.straightV, 'Függőleges'),
    (EditorPiece.cornerNE, 'Kanyar É-K'),
    (EditorPiece.cornerNW, 'Kanyar É-Ny'),
    (EditorPiece.cornerSE, 'Kanyar D-K'),
    (EditorPiece.cornerSW, 'Kanyar D-Ny'),
  ];

  static const _switchPieces = [
    (EditorPiece.switchCircle, 'Kör (90°)'),
    (EditorPiece.switchRectangle, 'Téglalap (sáv)'),
    (EditorPiece.switchTriangle, 'Háromszög (Y)'),
  ];

  static const _tramPieces = [
    (EditorPiece.tramGreen, 'Zöld (W/S + bal SHIFT)'),
    (EditorPiece.tramRed, 'Piros (Nyilak + jobb SHIFT)'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 224,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(right: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _ShelfSection(
              title: '1. Sínek',
              items: _railPieces,
              controller: controller,
              columns: 2,
            ),
            const SizedBox(height: 14),
            _ShelfSection(
              title: '2. Váltók',
              items: _switchPieces,
              controller: controller,
              columns: 2,
            ),
            const SizedBox(height: 14),
            _ShelfSection(
              title: '3. Villamosok',
              items: _tramPieces,
              controller: controller,
              columns: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfSection extends StatelessWidget {
  const _ShelfSection({
    required this.title,
    required this.items,
    required this.controller,
    required this.columns,
  });

  final String title;
  final List<(EditorPiece, String)> items;
  final EditorController controller;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: columns == 1 ? 2.8 : 1.12,
          children: [
            for (final (piece, label) in items)
              _ShelfTile(
                piece: piece,
                label: label,
                selected: controller.selectedPiece == piece,
                onTap: () => controller.selectPiece(
                  controller.selectedPiece == piece ? null : piece,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ShelfTile extends StatelessWidget {
  const _ShelfTile({
    required this.piece,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final EditorPiece piece;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tile = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E3A8A) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF60A5FA) : const Color(0xFF334155),
            width: selected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: CustomPaint(painter: EditorPiecePainter(piece: piece)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFFE2E8F0)),
            ),
          ],
        ),
      ),
    );

    return Draggable<EditorDragPayload>(
      data: EditorDragPayload.fromShelf(piece),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xCC0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF60A5FA), width: 1.5),
          ),
          child: CustomPaint(painter: EditorPiecePainter(piece: piece)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.45, child: tile),
      child: tile,
    );
  }
}
