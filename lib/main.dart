import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/audio_service.dart';
import 'core/game_log.dart';
import 'core/sticky_keys_guard.dart';
import 'game/editor/editor_controller.dart';
import 'game/levels/level_data.dart';
import 'game/levels/level_repository.dart';
import 'ui/screens/editor_screen.dart';
import 'ui/screens/level_select_screen.dart';
import 'ui/screens/main_menu_screen.dart';
import 'ui/screens/race_screen.dart';
import 'ui/widgets/log_overlay_window.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Players tap SHIFT fast: keep Windows' five-times-SHIFT prompt away while the game is in front.
  final stickyKeys = StickyKeysGuard()..suspendHotkey();
  AppLifecycleListener(
    onResume: stickyKeys.suspendHotkey,
    onInactive: stickyKeys.restore,
    onDetach: stickyKeys.restore,
    onExitRequested: () async {
      stickyKeys.restore();
      return AppExitResponse.exit;
    },
  );
  runApp(const TramsApp());
}

enum _AppRoute { menu, levelSelect, editor, race }

/// App root: dark MaterialApp coordinating menu, campaign levels, editor, and race.
class TramsApp extends StatefulWidget {
  /// Creates the root [TramsApp] with an optional custom [audio] service for tests.
  const TramsApp({super.key, this.audio});

  final AudioService? audio;

  @override
  State<TramsApp> createState() => _TramsAppState();
}

class _TramsAppState extends State<TramsApp> {
  final EditorController _editorController = EditorController();
  late final AudioService _ownedAudio = AudioService();
  List<LevelData> _levels = const [];
  final Set<String> _completedIds = <String>{};
  _AppRoute _route = _AppRoute.menu;
  LevelData? _raceLevel;
  int? _campaignIndex;
  bool _showLogOverlay = true;

  AudioService get _audio => widget.audio ?? _ownedAudio;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
    _loadLevels();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    _editorController.dispose();
    if (widget.audio == null) {
      _ownedAudio.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLevels() async {
    try {
      final loaded = await LevelRepository().loadAll();
      if (!mounted) return;
      setState(() => _levels = loaded);
    } on Object catch (error) {
      GameLog.event('level', 'Failed to preload campaign levels: $error');
    }
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.f3) {
      return false;
    }
    setState(() => _showLogOverlay = !_showLogOverlay);
    return true;
  }

  void _startCampaignLevel(int index) {
    setState(() {
      _campaignIndex = index;
      _raceLevel = index < _levels.length ? _levels[index] : null;
      _route = _AppRoute.race;
    });
  }

  void _startCustomRace(LevelData level) {
    setState(() {
      _campaignIndex = null;
      _raceLevel = level;
      _route = _AppRoute.race;
    });
  }

  void _markCurrentCompleted() {
    final idx = _campaignIndex;
    if (idx == null || idx < 0 || idx >= _levels.length) return;
    setState(() => _completedIds.add(_levels[idx].id));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Super Hot Imperfect Form Trams',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Stack(
        children: [
          _buildRouteBody(),
          if (_showLogOverlay)
            const Positioned(right: 16, bottom: 16, child: LogOverlayWindow()),
        ],
      ),
    );
  }

  Widget _buildRouteBody() {
    return switch (_route) {
      _AppRoute.menu => ValueListenableBuilder<bool>(
        valueListenable: _audio.isMuted,
        builder: (context, isMuted, _) => MainMenuScreen(
          onStartCampaign: () => _startCampaignLevel(0),
          onOpenLevelSelect: () =>
              setState(() => _route = _AppRoute.levelSelect),
          onOpenEditor: () => setState(() => _route = _AppRoute.editor),
          isMuted: isMuted,
          onToggleMute: _audio.toggleMute,
          completedCount: _completedIds.length,
          totalLevels: _levels.isEmpty ? 1 : _levels.length,
        ),
      ),
      _AppRoute.levelSelect => LevelSelectScreen(
        levels: _levels,
        completedIds: _completedIds,
        onSelectIndex: _startCampaignLevel,
        onBack: () => setState(() => _route = _AppRoute.menu),
        onOpenEditor: () => setState(() => _route = _AppRoute.editor),
      ),
      _AppRoute.editor => EditorScreen(
        controller: _editorController,
        onStartRace: _startCustomRace,
        onPlayDefault: () => _startCampaignLevel(0),
        onBackToMenu: () => setState(() => _route = _AppRoute.menu),
      ),
      _AppRoute.race => _buildRaceScreen(),
    };
  }

  Widget _buildRaceScreen() {
    final idx = _campaignIndex;
    final hasNext = idx != null && idx + 1 < _levels.length;
    return RaceScreen(
      level: _raceLevel,
      audio: _audio,
      onBackToEditor: () => setState(() => _route = _AppRoute.editor),
      onLevelSelect: () => setState(() => _route = _AppRoute.levelSelect),
      onMainMenu: () => setState(() => _route = _AppRoute.menu),
      onNextLevel: hasNext ? () => _startCampaignLevel(idx + 1) : null,
      onGoalMet: _markCurrentCompleted,
    );
  }
}
