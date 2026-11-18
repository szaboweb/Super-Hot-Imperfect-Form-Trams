import 'package:flutter/material.dart';

import '../../game/levels/level_data.dart';

/// Grid/list screen letting the player pick any asset level and inspect completion.
class LevelSelectScreen extends StatelessWidget {
  /// Creates the [LevelSelectScreen] for [levels] and [completedIds].
  const LevelSelectScreen({
    super.key,
    required this.levels,
    required this.completedIds,
    required this.onSelectIndex,
    required this.onBack,
    required this.onOpenEditor,
  });

  final List<LevelData> levels;
  final Set<String> completedIds;
  final ValueChanged<int> onSelectIndex;
  final VoidCallback onBack;
  final VoidCallback onOpenEditor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: levels.isEmpty
                ? const Center(
                    child: Text(
                      'Nincs betölthető pálya.',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: levels.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _LevelCard(
                      index: index,
                      level: levels[index],
                      isCompleted: completedIds.contains(levels[index].id),
                      onTap: () => onSelectIndex(index),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: onBack,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFCBD5E1),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Vissza'),
          ),
          const SizedBox(width: 14),
          const Text(
            'Pályaválasztó',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF1F5F9),
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onOpenEditor,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF38BDF8),
              side: const BorderSide(color: Color(0xFF0284C7)),
            ),
            icon: const Icon(Icons.grid_on, size: 18),
            label: const Text('Pályaszerkesztő'),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.index,
    required this.level,
    required this.isCompleted,
    required this.onTap,
  });

  final int index;
  final LevelData level;
  final bool isCompleted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final players = level.spawns.where((s) => s.controls != null).length;
    final aiCount = level.spawns.where((s) => s.controls == null).length;
    return Material(
      color: const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCompleted
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF1E293B),
            ),
          ),
          child: Row(
            children: [
              _IndexBadge(number: index + 1, isCompleted: isCompleted),
              const SizedBox(width: 14),
              Expanded(child: _buildDetails(players, aiCount)),
              if (isCompleted) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x263DDC84),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF3DDC84)),
                  ),
                  child: const Text(
                    'Teljesítve',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3DDC84),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              FilledButton.tonalIcon(
                onPressed: onTap,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Indítás'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(int players, int aiCount) {
    final modeText = aiCount > 0
        ? '$players játékos · $aiCount GÉPI'
        : '$players játékos';
    final cityPrefix = level.city.isEmpty ? '' : '${level.city} · ';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          level.displayTitle,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF8FAFC),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$cityPrefix$modeText · ${level.crossovers.length} váltó · '
          'Cél: ${level.crashGoal} ütközés',
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }
}

class _IndexBadge extends StatelessWidget {
  const _IndexBadge({required this.number, required this.isCompleted});

  final int number;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFF14532D) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$number',
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Color(0xFFF8FAFC),
        ),
      ),
    );
  }
}
