import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../audio/audio_service.dart';
import '../../game/levels/level_data.dart';
import '../../game/tram_game.dart';
import '../widgets/pause_overlay.dart';
import 'result_screen.dart';

/// Hosts [TramGame] for either a custom editor [level] or a campaign asset level.
class RaceScreen extends StatefulWidget {
  /// Creates a [RaceScreen] with optional campaign navigation and [audio].
  const RaceScreen({
    super.key,
    this.level,
    required this.onBackToEditor,
    this.audio,
    this.onNextLevel,
    this.onLevelSelect,
    this.onMainMenu,
    this.onGoalMet,
  });

  final LevelData? level;
  final VoidCallback onBackToEditor;
  final AudioService? audio;
  final VoidCallback? onNextLevel;
  final VoidCallback? onLevelSelect;
  final VoidCallback? onMainMenu;
  final VoidCallback? onGoalMet;

  @override
  State<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends State<RaceScreen> {
  late TramGame _game;
  final ValueNotifier<bool> _fallbackMuted = ValueNotifier<bool>(false);
  bool _paused = false;
  bool _notifiedGoal = false;

  @override
  void initState() {
    super.initState();
    _initGame();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void didUpdateWidget(covariant RaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      _detachGoalListener();
      _initGame();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _detachGoalListener();
    _fallbackMuted.dispose();
    super.dispose();
  }

  void _initGame() {
    _paused = false;
    _notifiedGoal = false;
    _game = TramGame(initialLevel: widget.level, audio: widget.audio);
    _game.goalMetNotifier.addListener(_onGoalChanged);
  }

  void _detachGoalListener() {
    _game.goalMetNotifier.removeListener(_onGoalChanged);
  }

  void _onGoalChanged() {
    if (!_game.goalMetNotifier.value || _notifiedGoal) return;
    _notifiedGoal = true;
    widget.onGoalMet?.call();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }
    _togglePause();
    return true;
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
      _game.paused = _paused;
    });
  }

  void _restart() {
    setState(() {
      _detachGoalListener();
      _initGame();
    });
  }

  void _toggleMute() {
    final audio = widget.audio;
    if (audio != null) {
      audio.toggleMute();
    } else {
      _fallbackMuted.value = !_fallbackMuted.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final muteListenable = widget.audio?.isMuted ?? _fallbackMuted;
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(key: ObjectKey(_game), game: _game),
          if (!_paused)
            Positioned.fill(
              child: ValueListenableBuilder<bool>(
                valueListenable: _game.goalMetNotifier,
                builder: (context, goalMet, _) {
                  if (!goalMet) return const SizedBox.shrink();
                  final score = _game.scoreSystem;
                  return Center(
                    child: ResultScreen(
                      crashCount: score.crashCount,
                      crashGoal: score.crashGoal,
                      onRestart: _restart,
                      onEditor: widget.onBackToEditor,
                      onNextLevel: widget.onNextLevel,
                      onLevelSelect: widget.onLevelSelect,
                    ),
                  );
                },
              ),
            ),
          if (!_paused)
            Positioned(top: 12, right: 12, child: _buildTopActions()),
          if (_paused)
            Positioned.fill(
              child: ValueListenableBuilder<bool>(
                valueListenable: muteListenable,
                builder: (context, isMuted, _) => PauseOverlay(
                  isMuted: isMuted,
                  onResume: _togglePause,
                  onRestart: _restart,
                  onToggleMute: _toggleMute,
                  onEditor: widget.onBackToEditor,
                  onLevelSelect: widget.onLevelSelect,
                  onMainMenu: widget.onMainMenu,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopActions() {
    return Row(
      children: [
        FilledButton.tonalIcon(
          onPressed: _togglePause,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xCC0F172A),
            foregroundColor: const Color(0xFFE2E8F0),
          ),
          icon: const Icon(Icons.pause, size: 18),
          label: const Text('Szünet'),
        ),
        const SizedBox(width: 8),
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
    );
  }
}
