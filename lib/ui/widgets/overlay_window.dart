import 'package:flutter/material.dart';

/// Reusable semi-transparent, collapsible floating window for in-app overlays.
class OverlayWindow extends StatefulWidget {
  const OverlayWindow({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.actions = const [],
    this.width = 380,
    this.maxHeight = 260,
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

  bool get _isCollapsed => widget.collapsed ?? _collapsed;

  void _toggle() {
    if (widget.onToggleCollapsed != null) {
      widget.onToggleCollapsed!();
      return;
    }
    setState(() => _collapsed = !_collapsed);
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = _isCollapsed;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: widget.width,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: widget.borderColor),
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
          children: [
            _OverlayHeader(
              title: widget.title,
              icon: widget.icon,
              actions: widget.actions,
              collapsed: collapsed,
              onToggle: _toggle,
            ),
            if (!collapsed)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: widget.maxHeight),
                child: widget.child,
              ),
          ],
        ),
      ),
    );
  }
}

class _OverlayHeader extends StatelessWidget {
  const _OverlayHeader({
    required this.title,
    required this.icon,
    required this.actions,
    required this.collapsed,
    required this.onToggle,
  });

  final String title;
  final IconData? icon;
  final List<Widget> actions;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('overlay_window_header'),
      onTap: onToggle,
      borderRadius: BorderRadius.vertical(
        top: const Radius.circular(9),
        bottom: collapsed ? const Radius.circular(9) : Radius.zero,
      ),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0x331E293B),
          border: collapsed
              ? null
              : const Border(bottom: BorderSide(color: Color(0x3394A3B8))),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: const Color(0xFF38BDF8)),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE2E8F0),
                ),
              ),
            ),
            ...actions,
            IconButton(
              key: const ValueKey('overlay_window_toggle'),
              onPressed: onToggle,
              tooltip: collapsed ? 'Kibontás' : 'Összecsukás',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 26, height: 26),
              iconSize: 16,
              color: const Color(0xFF94A3B8),
              icon: Icon(collapsed ? Icons.expand_less : Icons.expand_more),
            ),
          ],
        ),
      ),
    );
  }
}
