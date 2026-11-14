import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';

import 'core/sticky_keys_guard.dart';
import 'game/editor/editor_controller.dart';
import 'game/levels/level_data.dart';
import 'ui/screens/editor_screen.dart';
import 'ui/screens/race_screen.dart';

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

/// App root: dark MaterialApp switching between [EditorScreen] and [RaceScreen].
class TramsApp extends StatefulWidget {
  const TramsApp({super.key});

  @override
  State<TramsApp> createState() => _TramsAppState();
}

class _TramsAppState extends State<TramsApp> {
  final EditorController _editorController = EditorController();
  bool _inRace = false;
  LevelData? _raceLevel;

  @override
  void dispose() {
    _editorController.dispose();
    super.dispose();
  }

  void _startCustomRace(LevelData level) {
    setState(() {
      _raceLevel = level;
      _inRace = true;
    });
  }

  void _startDefaultRace() {
    setState(() {
      _raceLevel = null;
      _inRace = true;
    });
  }

  void _backToEditor() {
    setState(() {
      _inRace = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Super Hot Imperfect Form Trams',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: _inRace
          ? RaceScreen(level: _raceLevel, onBackToEditor: _backToEditor)
          : EditorScreen(
              controller: _editorController,
              onStartRace: _startCustomRace,
              onPlayDefault: _startDefaultRace,
            ),
    );
  }
}
