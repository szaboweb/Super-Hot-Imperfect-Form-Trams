import 'package:flutter/material.dart';

import 'overlay_window.dart';

/// Translucent pause menu overlay toggled via ESC or the top-right pause button.
class PauseOverlay extends StatelessWidget {
  /// Creates a [PauseOverlay] with resume, restart, audio, and navigation actions.
  const PauseOverlay({
    super.key,
    required this.isMuted,
    required this.onResume,
    required this.onRestart,
    required this.onToggleMute,
    required this.onEditor,
    this.onLevelSelect,
    this.onMainMenu,
  });

  final bool isMuted;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onToggleMute;
  final VoidCallback onEditor;
  final VoidCallback? onLevelSelect;
  final VoidCallback? onMainMenu;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xB805080F),
      child: Center(
        child: OverlayWindow(
          title: 'Szünet',
          icon: Icons.pause_circle_outline,
          width: 320,
          maxHeight: 380,
          backgroundColor: const Color(0xF20F172A),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: onResume,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Folytatás'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onRestart,
                  style: _buttonStyle(const Color(0xFFE2E8F0)),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Újraindítás'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onToggleMute,
                  style: _buttonStyle(
                    isMuted ? const Color(0xFFFCA5A5) : const Color(0xFFCBD5E1),
                  ),
                  icon: Icon(
                    isMuted ? Icons.volume_off : Icons.volume_up,
                    size: 18,
                  ),
                  label: Text(isMuted ? 'Hang: Némítva' : 'Hang: Be'),
                ),
                if (onLevelSelect != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onLevelSelect,
                    style: _buttonStyle(const Color(0xFFE2E8F0)),
                    icon: const Icon(Icons.route, size: 18),
                    label: const Text('Pályaválasztó'),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onEditor,
                  style: _buttonStyle(const Color(0xFF334155), text: true),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Szerkesztő'),
                ),
                if (onMainMenu != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onMainMenu,
                    style: _buttonStyle(const Color(0xFF94A3B8)),
                    icon: const Icon(Icons.home_outlined, size: 18),
                    label: const Text('Főmenü'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  ButtonStyle _buttonStyle(Color fg, {bool text = false}) =>
      OutlinedButton.styleFrom(
        foregroundColor: text ? const Color(0xFF38BDF8) : fg,
        side: const BorderSide(color: Color(0xFF334155)),
      );
}
