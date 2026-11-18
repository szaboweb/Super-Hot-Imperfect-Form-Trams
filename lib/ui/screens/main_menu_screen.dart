import 'package:flutter/material.dart';

/// Full-screen main menu with campaign entry, level select, editor, sound toggle, and controls.
class MainMenuScreen extends StatelessWidget {
  /// Creates the [MainMenuScreen] with navigation and audio callbacks.
  const MainMenuScreen({
    super.key,
    required this.onStartCampaign,
    required this.onOpenLevelSelect,
    required this.onOpenEditor,
    required this.isMuted,
    required this.onToggleMute,
    this.completedCount = 0,
    this.totalLevels = 1,
  });

  final VoidCallback onStartCampaign;
  final VoidCallback onOpenLevelSelect;
  final VoidCallback onOpenEditor;
  final bool isMuted;
  final VoidCallback onToggleMute;
  final int completedCount;
  final int totalLevels;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildActionCard(),
                const SizedBox(height: 16),
                _buildControlsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x26FFB627),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFFFB627)),
          ),
          child: const Text(
            'GAME OFF 2026 · TÉMA: SHIFT',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Color(0xFFFFB627),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Super Hot Imperfect Form Trams',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFFF8FAFC),
            letterSpacing: 0.3,
          ),
        ),
        if (totalLevels > 0) ...[
          const SizedBox(height: 6),
          Text(
            '$completedCount / $totalLevels pálya teljesítve',
            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
        ],
      ],
    );
  }

  Widget _buildActionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: onStartCampaign,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text(
              'Kampány indítása',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onOpenLevelSelect,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE2E8F0),
              side: const BorderSide(color: Color(0xFF334155)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.route, size: 19),
            label: const Text('Pályaválasztó'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onOpenEditor,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF38BDF8),
              side: const BorderSide(color: Color(0xFF0284C7)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.grid_on, size: 19),
            label: const Text('Pályaszerkesztő'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onToggleMute,
            style: OutlinedButton.styleFrom(
              foregroundColor: isMuted
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFFCBD5E1),
              side: const BorderSide(color: Color(0xFF334155)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up, size: 19),
            label: Text(isMuted ? 'Hang: Némítva' : 'Hang: Be'),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Irányítás',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF1F5F9),
            ),
          ),
          SizedBox(height: 8),
          _ControlRow(
            dotColor: Color(0xFF3DDC84),
            text: 'Zöld villamos: W / S · Bal SHIFT (váltó)',
          ),
          SizedBox(height: 4),
          _ControlRow(
            dotColor: Color(0xFFE5483B),
            text: 'Piros villamos: Fel / Le · Jobb SHIFT (váltó)',
          ),
          SizedBox(height: 4),
          _ControlRow(
            dotColor: Color(0xFF94A3B8),
            text: 'Szünet: ESC · Napló: F3',
          ),
        ],
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({required this.dotColor, required this.text});

  final Color dotColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFFCBD5E1)),
          ),
        ),
      ],
    );
  }
}
