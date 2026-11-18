import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_controller.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_data.dart';
import 'package:super_hot_imperfect_form_trams/ui/screens/editor_screen.dart';
import 'package:super_hot_imperfect_form_trams/ui/screens/level_select_screen.dart';
import 'package:super_hot_imperfect_form_trams/ui/screens/main_menu_screen.dart';
import 'package:super_hot_imperfect_form_trams/ui/screens/result_screen.dart';
import 'package:super_hot_imperfect_form_trams/ui/widgets/pause_overlay.dart';

LevelData _sampleLevel({String id = 'budapest_01_rakpart', String? name}) {
  return LevelData.fromJson({
    'id': id,
    'name': ?name,
    'city': 'Budapest',
    'segments': [
      {
        'id': 'loop_a',
        'end': 'connected',
        'nextSegment': 'loop_a',
        'points': [
          [0, 0],
          [100, 0],
          [100, 100],
          [0, 0],
        ],
      },
    ],
    'spawns': [
      {'segment': 'loop_a', 'time': 0, 'speed': 150, 'controls': 'wasd'},
      {'segment': 'loop_a', 'time': 1, 'speed': 140},
    ],
    'goal': {'crashes': 2},
  });
}

void main() {
  test('LevelData.displayTitle prefers explicit name and humanizes id', () {
    expect(_sampleLevel().displayTitle, 'Budapest 01 Rakpart');
    expect(
      _sampleLevel(name: 'Rakparti Csapda').displayTitle,
      'Rakparti Csapda',
    );
  });

  testWidgets('MainMenuScreen triggers actions and toggles mute label', (
    tester,
  ) async {
    var campaign = 0;
    var select = 0;
    var editor = 0;
    var muted = false;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          home: MainMenuScreen(
            onStartCampaign: () => campaign++,
            onOpenLevelSelect: () => select++,
            onOpenEditor: () => editor++,
            isMuted: muted,
            onToggleMute: () => setState(() => muted = !muted),
            completedCount: 1,
            totalLevels: 3,
          ),
        ),
      ),
    );

    expect(find.text('1 / 3 pálya teljesítve'), findsOneWidget);
    expect(find.text('Hang: Be'), findsOneWidget);
    expect(find.textContaining('Bal SHIFT'), findsOneWidget);

    await tester.tap(find.text('Kampány indítása'));
    await tester.tap(find.text('Pályaválasztó'));
    await tester.tap(find.text('Pályaszerkesztő'));
    await tester.tap(find.text('Hang: Be'));
    await tester.pump();

    expect(campaign, 1);
    expect(select, 1);
    expect(editor, 1);
    expect(find.text('Hang: Némítva'), findsOneWidget);
  });

  testWidgets('LevelSelectScreen shows badges and selects level index', (
    tester,
  ) async {
    final levels = [
      _sampleLevel(id: 'lvl_1', name: 'Rakparti Csapda'),
      _sampleLevel(id: 'lvl_2'),
    ];
    int? picked;
    var back = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: LevelSelectScreen(
          levels: levels,
          completedIds: const {'lvl_1'},
          onSelectIndex: (i) => picked = i,
          onBack: () => back++,
          onOpenEditor: () {},
        ),
      ),
    );

    expect(find.text('Rakparti Csapda'), findsOneWidget);
    expect(find.text('Teljesítve'), findsOneWidget);
    expect(find.textContaining('1 játékos · 1 GÉPI'), findsWidgets);

    await tester.tap(find.text('Rakparti Csapda'));
    await tester.tap(find.text('Vissza'));
    expect(picked, 0);
    expect(back, 1);
  });

  testWidgets('ResultScreen and PauseOverlay fire callbacks cleanly', (
    tester,
  ) async {
    var next = 0;
    var restart = 0;
    var resume = 0;
    var menu = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ResultScreen(
                crashCount: 2,
                crashGoal: 2,
                onNextLevel: () => next++,
                onRestart: () => restart++,
                onEditor: () {},
              ),
              PauseOverlay(
                isMuted: true,
                onResume: () => resume++,
                onRestart: () => restart++,
                onToggleMute: () {},
                onEditor: () {},
                onMainMenu: () => menu++,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Cél teljesítve! (2/2 ütközés)'), findsOneWidget);
    await tester.tap(find.text('Folytatás'));
    await tester.tap(find.text('Főmenü'));
    expect(resume, 1);
    expect(menu, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResultScreen(
            crashCount: 1,
            crashGoal: 1,
            onNextLevel: () => next++,
            onRestart: () => restart++,
            onEditor: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Következő pálya'));
    await tester.tap(find.text('Újraindítás'));
    expect(next, 1);
    expect(restart, 1);
  });

  testWidgets('EditorScreen shows Menü button only when onBackToMenu is set', (
    tester,
  ) async {
    final controller = EditorController();
    addTearDown(controller.dispose);
    var backToMenu = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: EditorScreen(
          controller: controller,
          onStartRace: (_) {},
          onPlayDefault: () {},
        ),
      ),
    );
    expect(find.text('Menü'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: EditorScreen(
          controller: controller,
          onStartRace: (_) {},
          onPlayDefault: () {},
          onBackToMenu: () => backToMenu++,
        ),
      ),
    );
    expect(find.text('Menü'), findsOneWidget);
    await tester.tap(find.text('Menü'));
    expect(backToMenu, 1);
  });
}
