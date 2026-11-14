import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../game/levels/level_data.dart';
import '../../game/tram_game.dart';

/// Hosts [TramGame] for either a custom editor [level] or the default asset level.
class RaceScreen extends StatefulWidget {
  const RaceScreen({super.key, this.level, required this.onBackToEditor});

  final LevelData? level;
  final VoidCallback onBackToEditor;

  @override
  State<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends State<RaceScreen> {
  late TramGame _game;

  @override
  void initState() {
    super.initState();
    _game = TramGame(initialLevel: widget.level);
  }

  void _restart() {
    setState(() {
      _game = TramGame(initialLevel: widget.level);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(key: ObjectKey(_game), game: _game),
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: _restart,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xCC0F172A),
                    foregroundColor: const Color(0xFFE2E8F0),
                  ),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Újraindítás'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: widget.onBackToEditor,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xE61E293B),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Szerkesztő'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
