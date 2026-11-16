import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/core/game_log.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_controller.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_piece.dart';
import 'package:super_hot_imperfect_form_trams/ui/widgets/log_overlay_window.dart';
import 'package:super_hot_imperfect_form_trams/ui/widgets/overlay_window.dart';

void main() {
  tearDown(() {
    GameLog.sink = null;
    GameLog.clear();
  });

  testWidgets('OverlayWindow renders semi-transparent and collapses/expands', (
    tester,
  ) async {
    var underlyingTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('underlying_canvas'),
                  onTap: () => underlyingTapped = true,
                ),
              ),
              const Positioned(
                right: 16,
                bottom: 16,
                child: OverlayWindow(
                  title: 'Teszt ablak',
                  icon: Icons.layers,
                  child: SizedBox(
                    height: 120,
                    child: Center(child: Text('Ablak tartalom')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Teszt ablak'), findsOneWidget);
    expect(find.text('Ablak tartalom'), findsOneWidget);

    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(OverlayWindow),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color!.a, lessThan(1.0));

    // Collapse by tapping the toggle button.
    await tester.tap(find.byKey(const ValueKey('overlay_window_toggle')));
    await tester.pump();
    expect(find.text('Ablak tartalom'), findsNothing);

    // Tapping where the body used to be reaches the underlying canvas.
    await tester.tapAt(const Offset(400, 300));
    expect(underlyingTapped, isTrue);

    // Expand again by tapping the header.
    await tester.tap(find.byKey(const ValueKey('overlay_window_header')));
    await tester.pump();
    expect(find.text('Ablak tartalom'), findsOneWidget);
  });

  testWidgets('LogOverlayWindow displays live GameLog and editor error logs', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(right: 16, bottom: 16, child: LogOverlayWindow()),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Nincsenek naplóbejegyzések.'), findsOneWidget);

    // Trigger an editor validation error (open-ended rail, missing trams).
    final controller = EditorController();
    controller.placePiece(EditorPiece.straightH, (col: 2, row: 2));

    final result = controller.buildLevel();
    expect(result.isValid, isFalse);

    await tester.pump();
    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.byKey(const ValueKey('log_overlay_copy')), findsOneWidget);
    expect(find.text('editor'), findsAtLeastNWidgets(1));
    expect(
      find.textContaining('Hiányzik a zöld villamos'),
      findsAtLeastNWidgets(1),
    );

    // Clear button empties the log overlay.
    await tester.tap(find.byKey(const ValueKey('log_overlay_clear')));
    await tester.pump();
    expect(find.text('Nincsenek naplóbejegyzések.'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('LogOverlayWindow filters entries and copy by category', (
    tester,
  ) async {
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    GameLog.event('editor', 'Szerkesztő üzenet');
    GameLog.event('tram', 'Villamos elindult');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(right: 16, bottom: 16, child: LogOverlayWindow()),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Napló (2)'), findsOneWidget);
    expect(find.text('Szerkesztő üzenet'), findsOneWidget);
    expect(find.text('Villamos elindult'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('log_filter_editor')));
    await tester.pump();

    expect(find.text('Napló (1/2)'), findsOneWidget);
    expect(find.text('Szerkesztő üzenet'), findsOneWidget);
    expect(find.text('Villamos elindult'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('log_overlay_copy')));
    await tester.pump();
    expect(copiedText, contains('Szerkesztő üzenet'));
    expect(copiedText, isNot(contains('Villamos elindult')));

    await tester.tap(find.byKey(const ValueKey('log_filter_all')));
    await tester.pump();

    expect(find.text('Napló (2)'), findsOneWidget);
    expect(find.text('Szerkesztő üzenet'), findsOneWidget);
    expect(find.text('Villamos elindult'), findsOneWidget);
  });
}
