import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/tram_game.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TramsApp());
}

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
