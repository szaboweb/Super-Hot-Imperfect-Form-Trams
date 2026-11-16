import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/game_log.dart';
import 'overlay_window.dart';

/// Live collapsible overlay window displaying [GameLog] entries.
class LogOverlayWindow extends StatefulWidget {
  const LogOverlayWindow({
    super.key,
    this.initiallyCollapsed = false,
    this.width = 400,
    this.maxHeight = 220,
  });

  final bool initiallyCollapsed;
  final double width;
  final double maxHeight;

  @override
  State<LogOverlayWindow> createState() => _LogOverlayWindowState();
}

class _LogOverlayWindowState extends State<LogOverlayWindow> {
  static const List<String?> _categories = [
    null,
    'editor',
    'switch',
    'tram',
    'level',
  ];

  final ScrollController _scrollController = ScrollController();
  int _lastCount = 0;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    GameLog.entriesNotifier.addListener(_onEntriesChanged);
  }

  @override
  void dispose() {
    GameLog.entriesNotifier.removeListener(_onEntriesChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onEntriesChanged() {
    final count = GameLog.entriesNotifier.value.length;
    if (count <= _lastCount) {
      _lastCount = count;
      return;
    }
    _lastCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  List<GameLogEntry> _filterEntries(List<GameLogEntry> entries) =>
      _selectedCategory == null
      ? entries
      : entries.where((e) => e.category == _selectedCategory).toList();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<GameLogEntry>>(
      valueListenable: GameLog.entriesNotifier,
      builder: (context, entries, _) {
        final filtered = _filterEntries(entries);
        final title = _selectedCategory != null
            ? 'Napló (${filtered.length}/${entries.length})'
            : 'Napló (${entries.length})';
        return OverlayWindow(
          title: title,
          icon: Icons.terminal,
          width: widget.width,
          maxHeight: widget.maxHeight,
          initiallyCollapsed: widget.initiallyCollapsed,
          actions: [
            IconButton(
              key: const ValueKey('log_overlay_copy'),
              onPressed: filtered.isEmpty ? null : () => _copyEntries(filtered),
              tooltip: 'Összes másolása',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 26, height: 26),
              iconSize: 15,
              color: const Color(0xFF94A3B8),
              icon: const Icon(Icons.copy_all_outlined),
            ),
            IconButton(
              key: const ValueKey('log_overlay_clear'),
              onPressed: entries.isEmpty ? null : GameLog.clear,
              tooltip: 'Napló törlése',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 26, height: 26),
              iconSize: 15,
              color: const Color(0xFF94A3B8),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LogFilterBar(
                categories: _categories,
                selected: _selectedCategory,
                onSelect: (cat) => setState(() => _selectedCategory = cat),
              ),
              Flexible(
                child: _LogEntryList(
                  entries: filtered,
                  scrollController: _scrollController,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static void _copyEntries(List<GameLogEntry> entries) {
    final text = entries
        .map((e) => '${e.timestamp.trim()} [${e.category}] ${e.message}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
  }
}

class _LogFilterBar extends StatelessWidget {
  const _LogFilterBar({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<String?> categories;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x2694A3B8))),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [for (final cat in categories) _buildChip(cat)],
      ),
    );
  }

  Widget _buildChip(String? cat) {
    final isSelected = selected == cat;
    final color = _categoryColor(cat);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: ValueKey('log_filter_${cat ?? "all"}'),
        onTap: () => onSelect(cat),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.24)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            cat ?? 'Mind',
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? color : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogEntryList extends StatelessWidget {
  const _LogEntryList({required this.entries, required this.scrollController});

  final List<GameLogEntry> entries;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Text(
          'Nincsenek naplóbejegyzések.',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      );
    }
    return SelectionArea(
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [for (final entry in entries) _LogEntryRow(entry: entry)],
        ),
      ),
    );
  }
}

class _LogEntryRow extends StatelessWidget {
  const _LogEntryRow({required this.entry});

  final GameLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final badgeColor = _categoryColor(entry.category);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.timestamp.trim(),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: badgeColor.withValues(alpha: 0.45)),
            ),
            child: Text(
              entry.category,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: badgeColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              entry.message,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFE2E8F0),
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _categoryColor(String? category) => switch (category) {
  'editor' => const Color(0xFFF59E0B),
  'switch' => const Color(0xFF38BDF8),
  'tram' => const Color(0xFF4ADE80),
  'level' => const Color(0xFFA78BFA),
  _ => const Color(0xFF94A3B8),
};
