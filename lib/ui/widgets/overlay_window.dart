import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Reusable semi-transparent, movable, resizable, collapsible floating window.
class OverlayWindow extends StatefulWidget {
  /// Creates an [OverlayWindow] with collapse, move, and resize controls.
  const OverlayWindow({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.actions = const [],
    this.width = 380,
    this.maxHeight = 260,
    this.minWidth = 220,
    this.minHeight = 90,
    this.collapsedWidth = 240,
    this.initiallyCollapsed = false,
    this.collapsed,
    this.onToggleCollapsed,
    this.backgroundColor = const Color(0xCC0F172A),
    this.borderColor = const Color(0x4D94A3B8),
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final List<Widget> actions;
  final double width;
  final double maxHeight;
  final double minWidth;
  final double minHeight;
  final double collapsedWidth;
  final bool initiallyCollapsed;
  final bool? collapsed;
  final VoidCallback? onToggleCollapsed;
  final Color backgroundColor;
  final Color borderColor;

  @override
  State<OverlayWindow> createState() => _OverlayWindowState();
}

class _OverlayWindowState extends State<OverlayWindow> {
  late bool _collapsed = widget.initiallyCollapsed;
  bool _editing = false;
  Offset _dragOffset = Offset.zero;
  late double _width = widget.width;
  late double _maxHeight = widget.maxHeight;
  bool _hasCustomHeight = false;

  bool get _isCollapsed => widget.collapsed ?? _collapsed;

  void _toggle() {
    final onToggle = widget.onToggleCollapsed;
    if (onToggle != null) {
      onToggle();
      return;
    }
    setState(() => _collapsed = !_collapsed);
  }

  void _toggleEditing() => setState(() => _editing = !_editing);

  void _handleDrag(DragUpdateDetails d) =>
      setState(() => _dragOffset += d.delta);

  void _handleResize(DragUpdateDetails d) {
    setState(() {
      _width = (_width + d.delta.dx).clamp(widget.minWidth, 900.0);
      _maxHeight = (_maxHeight + d.delta.dy).clamp(widget.minHeight, 700.0);
      _hasCustomHeight = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = _isCollapsed;
    final renderedWidth = collapsed
        ? math.min(_width, widget.collapsedWidth)
        : _width;
    return Transform.translate(
      offset: _dragOffset,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: renderedWidth,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _editing ? const Color(0xFF38BDF8) : widget.borderColor,
              width: _editing ? 1.5 : 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_buildHeader(collapsed), if (!collapsed) _buildBody()],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool collapsed) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0x331E293B),
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(9),
          bottom: collapsed ? const Radius.circular(9) : Radius.zero,
        ),
        border: collapsed
            ? null
            : const Border(bottom: BorderSide(color: Color(0x3394A3B8))),
      ),
      child: Row(
        children: [
          _headerButton(
            key: const ValueKey('overlay_window_edit'),
            icon: _editing ? Icons.check : Icons.edit_outlined,
            color: _editing ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
            tooltip: _editing ? 'Szerkesztés kész' : 'Átmozgatás / átméretezés',
            onPressed: _toggleEditing,
          ),
          const SizedBox(width: 4),
          Expanded(child: _buildTitleRegion()),
          ...widget.actions,
          _headerButton(
            key: const ValueKey('overlay_window_toggle'),
            icon: collapsed ? Icons.open_in_full : Icons.minimize,
            color: const Color(0xFF94A3B8),
            tooltip: collapsed ? 'Visszanagyítás' : 'Kicsinyítés',
            onPressed: _toggle,
          ),
        ],
      ),
    );
  }

  Widget _headerButton({
    required Key key,
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      key: key,
      onPressed: onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 26, height: 26),
      iconSize: 15,
      color: color,
      icon: Icon(icon),
    );
  }

  Widget _buildTitleRegion() {
    final content = SizedBox(
      height: 34,
      child: Row(
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 15, color: const Color(0xFF38BDF8)),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              widget.title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE2E8F0),
              ),
            ),
          ),
        ],
      ),
    );
    if (_editing) {
      return MouseRegion(
        cursor: SystemMouseCursors.move,
        child: GestureDetector(
          key: const ValueKey('overlay_window_header'),
          behavior: HitTestBehavior.opaque,
          onPanUpdate: _handleDrag,
          child: content,
        ),
      );
    }
    return InkWell(
      key: const ValueKey('overlay_window_header'),
      onTap: _toggle,
      borderRadius: BorderRadius.circular(6),
      child: content,
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: _hasCustomHeight ? _maxHeight : 0,
              maxHeight: _maxHeight,
            ),
            child: widget.child,
          ),
        ),
        if (_editing)
          Positioned(right: 0, bottom: 0, child: _buildResizeHandle()),
      ],
    );
  }

  Widget _buildResizeHandle() {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeDownRight,
      child: GestureDetector(
        key: const ValueKey('overlay_window_resize'),
        behavior: HitTestBehavior.opaque,
        onPanUpdate: _handleResize,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.all(3),
              child: Icon(Icons.south_east, size: 14, color: Color(0xFF38BDF8)),
            ),
          ),
        ),
      ),
    );
  }
}
