import 'dart:ui' show AppExitResponse;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'core/sticky_keys_guard.dart';
import 'game/tram_game.dart';

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

/// App root: a dark MaterialApp hosting the [GameWidget] with [TramGame].
class TramsApp extends StatelessWidget {
  const TramsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Super Hot Imperfect Form Trams',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(body: GameWidget(game: TramGame())),
    );
  }
}
