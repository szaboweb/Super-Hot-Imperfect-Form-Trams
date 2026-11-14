import 'package:flutter/material.dart';

import '../../game/editor/editor_controller.dart';
import '../../game/levels/level_data.dart';
import '../widgets/editor_grid_canvas.dart';
import '../widgets/editor_sidebar.dart';

/// Full-screen track editor: left piece shelves, 16x10 grid canvas, validation & START.
class EditorScreen extends StatelessWidget {
  const EditorScreen({
    super.key,
    required this.controller,
    required this.onStartRace,
    required this.onPlayDefault,
  });

  final EditorController controller;
  final ValueChanged<LevelData> onStartRace;
  final VoidCallback onPlayDefault;

  void _handleStart() {
    final result = controller.buildLevel();
    if (result.isValid) {
      onStartRace(result.level);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: Column(
        children: [
          _EditorToolbar(
            controller: controller,
            onStart: _handleStart,
            onPlayDefault: onPlayDefault,
          ),
          Expanded(
            child: Row(
              children: [
                EditorSidebar(controller: controller),
                Expanded(
                  child: Column(
                    children: [
                      _FeedbackBanner(controller: controller),
                      Expanded(child: EditorGridCanvas(controller: controller)),
                      const _HintBar(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.controller,
    required this.onStart,
    required this.onPlayDefault,
  });

  final EditorController controller;
  final VoidCallback onStart;
  final VoidCallback onPlayDefault;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Row(
          children: [
            const Icon(Icons.tram, color: Color(0xFF38BDF8), size: 22),
            const SizedBox(width: 10),
            const Text(
              'Pályaszerkesztő',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF1F5F9),
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: controller.toggleEraseMode,
              style: OutlinedButton.styleFrom(
                foregroundColor: controller.eraseMode
                    ? const Color(0xFFFCA5A5)
                    : const Color(0xFFCBD5E1),
                backgroundColor: controller.eraseMode
                    ? const Color(0x33EF4444)
                    : null,
                side: BorderSide(
                  color: controller.eraseMode
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF334155),
                ),
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Törlés'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: controller.clear,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFCBD5E1),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              icon: const Icon(Icons.layers_clear, size: 18),
              label: const Text('Ürítés'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onPlayDefault,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF93C5FD),
                side: const BorderSide(color: Color(0xFF1E40AF)),
              ),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Alap pálya'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.play_arrow, size: 20),
              label: const Text(
                'START',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.errors.isNotEmpty) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x2AEF4444),
              border: Border.all(color: const Color(0xFFEF4444)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 110),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final err in controller.errors)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• $err',
                          style: const TextStyle(
                            color: Color(0xFFFECACA),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }
        final status = controller.statusMessage;
        if (status != null) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x2AF59E0B),
              border: Border.all(color: const Color(0xFFF59E0B)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 12.5),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _HintBar extends StatelessWidget {
  const _HintBar();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Text(
        'Húzd a síneket és villamosokat a rácsra · Cellán belüli húzással mozgatható · Jobb klikk: törlés',
        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
      ),
    );
  }
}
