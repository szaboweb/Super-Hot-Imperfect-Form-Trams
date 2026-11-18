import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/audio/audio_service.dart';
import 'package:super_hot_imperfect_form_trams/game/components/tram_trailer_component.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_data.dart';
import 'package:super_hot_imperfect_form_trams/game/tram_game.dart';
import 'package:super_hot_imperfect_form_trams/main.dart';
import 'package:super_hot_imperfect_form_trams/ui/screens/editor_screen.dart';
import 'package:super_hot_imperfect_form_trams/ui/screens/level_select_screen.dart';
import 'package:super_hot_imperfect_form_trams/ui/screens/main_menu_screen.dart';
import 'package:super_hot_imperfect_form_trams/ui/widgets/log_overlay_window.dart';

void main() {
  testWidgets(
    'TramGame mounts TramTrailerComponent for initial and delayed spawns',
    (tester) async {
      final level = LevelData.fromJson({
        'id': 'trailer_spawn_test',
        'bounds': {'width': 1040, 'height': 680},
        'segments': [
          {
            'id': 'loop',
            'end': 'connected',
            'nextSegment': 'loop',
            'points': [
              [-200, -100],
              [200, -100],
              [200, 100],
              [-200, 100],
              [-200, -100],
            ],
          },
        ],
        'spawns': [
          {'segment': 'loop', 'time': 0, 'speed': 80, 'startDistance': 0},
          {'segment': 'loop', 'time': 1.0, 'speed': 80, 'startDistance': 300},
        ],
        'goal': {'crashes': 1},
      });
      final game = TramGame(initialLevel: level);
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await tester.pump();
      await tester.pump();

      expect(game.world.children.whereType<TramTrailerComponent>().length, 1);

      game.update(1.1);
      game.update(0.016);
      expect(game.trams.length, 2);
      expect(game.world.children.whereType<TramTrailerComponent>().length, 2);
    },
  );

  testWidgets(
    'TramGame dispatches switch, crash, splash, and goal audio cues',
    (tester) async {
      final played = <String>[];
      final audio = AudioService(
        backend: (file, _) async => played.add(file),
        minRepeatIntervalMs: 0,
      );
      addTearDown(audio.dispose);

      final level = LevelData.fromJson({
        'id': 'audio_events_test',
        'bounds': {'width': 1040, 'height': 680},
        'segments': [
          {
            'id': 'ns',
            'end': 'connected',
            'nextSegment': 'ns',
            'points': [
              [0, 200],
              [0, -200],
              [200, -200],
              [200, 200],
              [0, 200],
            ],
          },
          {
            'id': 'ew',
            'end': 'connected',
            'nextSegment': 'ew',
            'points': [
              [-200, 0],
              [200, 0],
              [200, 200],
              [-200, 200],
              [-200, 0],
            ],
          },
          {
            'id': 'spur',
            'end': 'river',
            'points': [
              [-400, -250],
              [-200, -250],
            ],
          },
        ],
        'spawns': [
          {
            'segment': 'ns',
            'time': 0,
            'speed': 100,
            'startDistance': 10,
            'controls': 'wasd',
          },
          {
            'segment': 'ew',
            'time': 0,
            'speed': 120,
            'startDistance': 560,
            'controls': 'arrows',
          },
          {'segment': 'ew', 'time': 0, 'speed': -120, 'startDistance': 620},
          {'segment': 'spur', 'time': 0, 'speed': 160, 'startDistance': 190},
        ],
        'goal': {'crashes': 2},
        'crossovers': [
          {
            'id': 'sw_center',
            'platformShape': 'circle',
            'x': 0,
            'y': 0,
            'links': [
              {'from': 'ns', 'to': 'ew'},
              {'from': 'ew', 'to': 'ns'},
            ],
          },
        ],
      });
      final game = TramGame(initialLevel: level, audio: audio);
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await tester.pump();
      await tester.pump();

      expect(game.trams[0].requestTurn(), isFalse);
      expect(played, contains('sfx/sfx_miss_01.wav'));

      game.trams[0].trackDistance = 195;
      game.update(0.4);
      expect(game.trams[0].requestTurn(), isTrue);
      expect(played, contains('sfx/sfx_switch_01.wav'));
      expect(played, contains('sfx/sfx_splash_01.wav'));
      expect(played, contains('sfx/sfx_crash_01.wav'));
      expect(played, contains('sfx/sfx_goal_01.wav'));
    },
  );

  testWidgets(
    'TramsApp starts on MainMenuScreen, shows log by default (F3 toggles), and navigates',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final audio = AudioService(backend: (_, _) async {});
      addTearDown(audio.dispose);

      await tester.pumpWidget(TramsApp(audio: audio));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(MainMenuScreen), findsOneWidget);
      expect(find.byType(LogOverlayWindow), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.f3);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.f3);
      await tester.pump();
      expect(find.byType(LogOverlayWindow), findsNothing);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.f3);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.f3);
      await tester.pump();
      expect(find.byType(LogOverlayWindow), findsOneWidget);

      await tester.tap(find.text('Pályaválasztó'));
      await tester.pump();
      expect(find.byType(LevelSelectScreen), findsOneWidget);

      await tester.tap(find.text('Pályaszerkesztő'));
      await tester.pump();
      expect(find.byType(EditorScreen), findsOneWidget);

      await tester.tap(find.text('Menü'));
      await tester.pump();
      expect(find.byType(MainMenuScreen), findsOneWidget);
    },
  );
}
