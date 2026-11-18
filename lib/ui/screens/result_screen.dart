import 'package:flutter/material.dart';

import '../widgets/overlay_window.dart';

/// End-of-level result card overlay shown when [crashGoal] is satisfied.
class ResultScreen extends StatelessWidget {
  /// Creates a [ResultScreen] displaying the exact crash-goal completion summary.
  const ResultScreen({
    super.key,
    required this.crashCount,
    required this.crashGoal,
    required this.onRestart,
    required this.onEditor,
    this.onNextLevel,
    this.onLevelSelect,
  });

  final int crashCount;
  final int crashGoal;
  final VoidCallback onRestart;
  final VoidCallback onEditor;
  final VoidCallback? onNextLevel;
  final VoidCallback? onLevelSelect;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OverlayWindow(
        title: 'Győzelem!',
        icon: Icons.emoji_events,
        width: 440,
        maxHeight: 220,
        backgroundColor: const Color(0xEB0F172A),
        borderColor: const Color(0xFF3DDC84),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF3DDC84),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Cél teljesítve! ($crashCount/$crashGoal ütközés)',
                      style: const TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (onNextLevel != null)
                    FilledButton.icon(
                      onPressed: onNextLevel,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.skip_next, size: 18),
                      label: const Text('Következő pálya'),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: onRestart,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Újraindítás'),
                  ),
                  if (onLevelSelect != null)
                    OutlinedButton.icon(
                      onPressed: onLevelSelect,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE2E8F0),
                        side: const BorderSide(color: Color(0xFF475569)),
                      ),
                      icon: const Icon(Icons.route, size: 18),
                      label: const Text('Pályaválasztó'),
                    ),
                  OutlinedButton.icon(
                    onPressed: onEditor,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF38BDF8),
                      side: const BorderSide(color: Color(0xFF0284C7)),
                    ),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Szerkesztő'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
