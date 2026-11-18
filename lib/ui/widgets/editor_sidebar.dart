import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../game/editor/editor_controller.dart';
import '../../game/editor/editor_grid.dart';
import '../../game/editor/editor_piece.dart';
import 'editor_piece_painter.dart';

/// Drag payload carried either from a sidebar shelf or from an existing grid cell.
class EditorDragPayload {
  /// Creates a drag payload originating from a sidebar shelf [piece].
  const EditorDragPayload.fromShelf(this.piece) : fromCell = null;

  /// Creates a drag payload originating from an existing grid [fromCell].
  const EditorDragPayload.fromGrid(this.piece, EditorCell this.fromCell);

  /// Piece being dragged.
  final EditorPiece piece;

  /// Original grid cell when moved, or `null` when dragged from a shelf.
  final EditorCell? fromCell;
}

/// Left scrollable sidebar containing the four piece shelves: Sínek, Váltók, Speciális, Villamosok.
class EditorSidebar extends StatefulWidget {
  /// Creates the left editor piece palette sidebar bound to [controller].
  const EditorSidebar({super.key, required this.controller});

  /// Editor state controller tracking piece selection.
  final EditorController controller;

  @override
  State<EditorSidebar> createState() => _EditorSidebarState();
}

class _EditorSidebarState extends State<EditorSidebar> {
  static const _shelves = [
    (
      title: '1. Sínek',
      columns: 2,
      items: [
        (EditorPiece.straightH, 'Vízszintes'),
        (EditorPiece.straightV, 'Függőleges'),
        (EditorPiece.cornerNE, 'Kanyar É-K'),
        (EditorPiece.cornerNW, 'Kanyar É-Ny'),
        (EditorPiece.cornerSE, 'Kanyar D-K'),
        (EditorPiece.cornerSW, 'Kanyar D-Ny'),
        (EditorPiece.crossing, 'Kereszteződés'),
        (EditorPiece.bufferStop, 'Ütközőbak'),
      ],
    ),
    (
      title: '2. Váltók',
      columns: 2,
      items: [
        (EditorPiece.switchCircle, 'Kör (90°)'),
        (EditorPiece.switchRectangle, 'Téglalap (sáv)'),
        (EditorPiece.switchTriangle, 'Háromszög (180°)'),
        (EditorPiece.switchY, 'Y váltó (kisív)'),
        (EditorPiece.gate, 'Sorompó'),
      ],
    ),
    (
      title: '3. Speciális',
      columns: 2,
      items: [
        (EditorPiece.railIce, 'Jeges sín (gyorsító)'),
        (EditorPiece.railMelted, 'Olvadt sín (lassító)'),
      ],
    ),
    (
      title: '4. Villamosok',
      columns: 1,
      items: [
        (EditorPiece.tramGreen, 'Zöld (W/S + bal SHIFT)'),
        (EditorPiece.tramRed, 'Piros (Nyilak + jobb SHIFT)'),
      ],
    ),
  ];

  late final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 224,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(right: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => _buildScrollableShelves(context),
      ),
    );
  }

  Widget _buildScrollableShelves(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        thickness: 8,
        radius: const Radius.circular(4),
        child: ListView(
          key: const Key('editor_sidebar_scroll'),
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 16, 16),
          children: [
            for (var i = 0; i < _shelves.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              _ShelfSection(
                title: _shelves[i].title,
                items: _shelves[i].items,
                controller: widget.controller,
                columns: _shelves[i].columns,
              ),
            ],
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
          childAspectRatio: columns == 1 ? 2.8 : 0.94,
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
    final tile = _buildTileContent();
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
          child: CustomPaint(painter: _buildPainter()),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.45, child: tile),
      child: tile,
    );
  }

  Widget _buildTileContent() {
    return InkWell(
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
                child: CustomPaint(painter: _buildPainter()),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.15,
                color: Color(0xFFE2E8F0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  EditorPiecePainter _buildPainter() => EditorPiecePainter(
    piece: piece,
    wyeStemSide: piece == EditorPiece.switchY
        ? EditorSide.south
        : EditorSide.south,
  );
}
