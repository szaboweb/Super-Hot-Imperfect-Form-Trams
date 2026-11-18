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
    GameLog.event('crash', 'Ütközés történt');
    GameLog.event('input', 'StickyKeys kikapcsolva');

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

    expect(find.text('Napló (4)'), findsOneWidget);
    expect(find.text('Szerkesztő üzenet'), findsOneWidget);
    expect(find.text('Villamos elindult'), findsOneWidget);
    expect(find.text('Ütközés történt'), findsOneWidget);
    expect(find.text('StickyKeys kikapcsolva'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('log_filter_editor')));
    await tester.pump();

    expect(find.text('Napló (1/4)'), findsOneWidget);
    expect(find.text('Szerkesztő üzenet'), findsOneWidget);
    expect(find.text('Villamos elindult'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('log_overlay_copy')));
    await tester.pump();
    expect(copiedText, contains('Szerkesztő üzenet'));
    expect(copiedText, isNot(contains('Villamos elindult')));

    await tester.tap(find.byKey(const ValueKey('log_filter_crash')));
    await tester.pump();
    expect(find.text('Napló (1/4)'), findsOneWidget);
    expect(find.text('Ütközés történt'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('log_filter_input')));
    await tester.pump();
    expect(find.text('Napló (1/4)'), findsOneWidget);
    expect(find.text('StickyKeys kikapcsolva'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('log_filter_all')));
    await tester.pump();

    expect(find.text('Napló (4)'), findsOneWidget);
    expect(find.text('Szerkesztő üzenet'), findsOneWidget);
    expect(find.text('Villamos elindult'), findsOneWidget);
  });

  testWidgets(
    'OverlayWindow minimizes/restores width and supports drag/resize edit mode',
    (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: OverlayWindow(
                    title: 'Mozgatható ablak',
                    icon: Icons.layers,
                    width: 320,
                    maxHeight: 160,
                    collapsedWidth: 220,
                    child: SizedBox(
                      height: 120,
                      child: Center(
                        child: ElevatedButton(
                          key: const ValueKey('overlay_inner_btn'),
                          onPressed: () => pressed++,
                          child: const Text('Gomb'),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final initialSize = tester.getSize(find.byType(OverlayWindow));
      expect(initialSize.width, 320);

      // Minimize shrinks width to collapsedWidth and hides the body.
      await tester.tap(find.byKey(const ValueKey('overlay_window_toggle')));
      await tester.pump();
      expect(find.text('Gomb'), findsNothing);
      expect(tester.getSize(find.byType(OverlayWindow)).width, 220);

      // Restore brings back the original width and body.
      await tester.tap(find.byKey(const ValueKey('overlay_window_toggle')));
      await tester.pump();
      expect(find.text('Gomb'), findsOneWidget);
      expect(tester.getSize(find.byType(OverlayWindow)).width, 320);

      // Toggle edit mode on: resize handle appears.
      expect(find.byKey(const ValueKey('overlay_window_resize')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('overlay_window_edit')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('overlay_window_resize')),
        findsOneWidget,
      );

      final beforeDragCenter = tester.getCenter(
        find.byKey(const ValueKey('overlay_inner_btn')),
      );
      await tester.drag(
        find.byKey(const ValueKey('overlay_window_header')),
        const Offset(-100, -60),
      );
      await tester.pump();
      final afterDragCenter = tester.getCenter(
        find.byKey(const ValueKey('overlay_inner_btn')),
      );
      expect(afterDragCenter.dx, lessThan(beforeDragCenter.dx - 50));
      expect(afterDragCenter.dy, lessThan(beforeDragCenter.dy - 30));

      // Shifted child button remains tappable at its new translated position.
      await tester.tap(find.byKey(const ValueKey('overlay_inner_btn')));
      await tester.pump();
      expect(pressed, 1);

      // Resize drag grows both width and height.
      final beforeResizeSize = tester.getSize(find.byType(OverlayWindow));
      await tester.drag(
        find.byKey(const ValueKey('overlay_window_resize')),
        const Offset(80, 50),
      );
      await tester.pump();
      final afterResizeSize = tester.getSize(find.byType(OverlayWindow));
      expect(afterResizeSize.width, greaterThan(beforeResizeSize.width));
      expect(afterResizeSize.height, greaterThan(beforeResizeSize.height));

      // Toggle edit mode off hides the resize handle.
      await tester.tap(find.byKey(const ValueKey('overlay_window_edit')));
      await tester.pump();
      expect(find.byKey(const ValueKey('overlay_window_resize')), findsNothing);
    },
  );
}
