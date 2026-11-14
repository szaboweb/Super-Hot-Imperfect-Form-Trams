import 'package:flutter/material.dart';

import '../../game/editor/editor_controller.dart';
import '../../game/editor/editor_grid.dart';
import '../../game/editor/editor_piece.dart';
import 'editor_piece_painter.dart';
import 'editor_sidebar.dart';

/// Interactive 16x10 grid canvas supporting drag-and-drop, move, tap, and right-click erase.
class EditorGridCanvas extends StatelessWidget {
  const EditorGridCanvas({super.key, required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final grid = controller.grid;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AspectRatio(
          aspectRatio: grid.cols / grid.rows,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A202C),
              border: Border.all(color: const Color(0xFF334155), width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => Column(
                children: [
                  for (var row = 0; row < grid.rows; row++)
                    Expanded(
                      child: Row(
                        children: [
                          for (var col = 0; col < grid.cols; col++)
                            Expanded(
                              child: _GridCellWidget(
                                cell: (col: col, row: row),
                                controller: controller,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GridCellWidget extends StatefulWidget {
  const _GridCellWidget({required this.cell, required this.controller});

  final EditorCell cell;
  final EditorController controller;

  @override
  State<_GridCellWidget> createState() => _GridCellWidgetState();
}

class _GridCellWidgetState extends State<_GridCellWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final grid = widget.controller.grid;
    final rail = grid.railAt(widget.cell);
    final tram = grid.tramAt(widget.cell);
    final topPiece = tram ?? rail;
    final hasError = widget.controller.errorCells.contains(widget.cell);

    return DragTarget<EditorDragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        final payload = details.data;
        if (payload.fromCell != null) {
          widget.controller.movePiece(payload.fromCell!, widget.cell);
        } else {
          widget.controller.placePiece(payload.piece, widget.cell);
        }
      },
      builder: (context, candidateData, _) {
        final isDragTarget = candidateData.isNotEmpty;
        final content = MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.controller.handleCellTap(widget.cell),
            onSecondaryTapUp: (_) => widget.controller.removeAt(widget.cell),
            child: _CellVisual(
              cell: widget.cell,
              rail: rail,
              tram: tram,
              hasError: hasError,
              isDragTarget: isDragTarget,
              hovered: _hovered,
            ),
          ),
        );

        if (topPiece == null) return content;

        return Draggable<EditorDragPayload>(
          data: EditorDragPayload.fromGrid(topPiece, widget.cell),
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 56,
              height: 56,
              child: CustomPaint(painter: EditorPiecePainter(piece: topPiece)),
            ),
          ),
          childWhenDragging: _CellVisual(
            cell: widget.cell,
            rail: tram != null ? rail : null,
            tram: null,
            hasError: hasError,
            isDragTarget: false,
            hovered: _hovered,
          ),
          child: content,
        );
      },
    );
  }
}

class _CellVisual extends StatelessWidget {
  const _CellVisual({
    required this.cell,
    required this.rail,
    required this.tram,
    required this.hasError,
    required this.isDragTarget,
    required this.hovered,
  });

  final EditorCell cell;
  final EditorPiece? rail;
  final EditorPiece? tram;
  final bool hasError;
  final bool isDragTarget;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final borderColor = _borderColor();
    final bgColor = _bgColor();

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(
          color: borderColor,
          width: (hasError || isDragTarget) ? 1.8 : 0.5,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (rail != null)
            CustomPaint(painter: EditorPiecePainter(piece: rail!)),
          if (tram != null)
            CustomPaint(painter: EditorPiecePainter(piece: tram!)),
          if (cell.row == 0 || cell.col == 0)
            Positioned(
              left: 2,
              top: 1,
              child: Text(
                '${cell.col + 1},${cell.row + 1}',
                style: const TextStyle(fontSize: 8, color: Color(0xFF475569)),
              ),
            ),
        ],
      ),
    );
  }

  Color _borderColor() {
    if (isDragTarget) return const Color(0xFF60A5FA);
    if (hasError) return const Color(0xFFEF4444);
    if (hovered) return const Color(0xFF64748B);
    return const Color(0xFF2D3748);
  }

  Color _bgColor() {
    if (isDragTarget) return const Color(0x333B82F6);
    if (hasError) return const Color(0x33EF4444);
    if (hovered) return const Color(0x1A94A3B8);
    return Colors.transparent;
  }
}
