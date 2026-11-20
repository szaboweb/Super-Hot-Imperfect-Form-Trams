import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_controller.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_piece.dart';
import 'package:super_hot_imperfect_form_trams/ui/widgets/editor_sidebar.dart';

void main() {
  testWidgets(
    'displays all 4 shelves, 4 T-switches, 8 Y-switches, scrolls and selects tramGreen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = EditorController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EditorSidebar(controller: controller)),
        ),
      );

      expect(find.text('1. Sínek'), findsOneWidget);
      expect(find.text('Kereszteződés'), findsOneWidget);
      expect(find.text('Ütközőbak'), findsOneWidget);

      final scrollFinder = find.byKey(const Key('editor_sidebar_scroll'));
      expect(scrollFinder, findsOneWidget);
      final scrollableFinder = find
          .descendant(of: scrollFinder, matching: find.byType(Scrollable))
          .first;
      final scrollable = tester.state<ScrollableState>(scrollableFinder);
      expect(scrollable.position.pixels, 0.0);

      Future<void> scrollDownUntilFound(Finder target) async {
        final pointer = TestPointer(1, PointerDeviceKind.mouse);
        final center = tester.getCenter(scrollFinder);
        tester.binding.handlePointerEvent(pointer.hover(center));
        for (var i = 0; i < 40 && target.evaluate().isEmpty; i++) {
          tester.binding.handlePointerEvent(
            pointer.scroll(const Offset(0, 120)),
          );
          await tester.pump();
        }
        expect(target, findsOneWidget);
        await Scrollable.ensureVisible(tester.element(target));
        await tester.pump();
      }

      await scrollDownUntilFound(find.text('2. Váltók'));
      expect(scrollable.position.pixels, greaterThan(0.0));

      for (final label in const [
        'T váltó ↑ (É)',
        'T váltó ↓ (D)',
        'T váltó → (K)',
        'T váltó ← (Ny)',
        'Y váltó ↑ bal',
        'Y váltó ↑ jobb',
        'Y váltó ↓ bal',
        'Y váltó ↓ jobb',
        'Y váltó → bal',
        'Y váltó → jobb',
        'Y váltó ← bal',
        'Y váltó ← jobb',
        'Sorompó',
      ]) {
        await scrollDownUntilFound(find.text(label));
      }

      await scrollDownUntilFound(find.text('3. Speciális'));
      await scrollDownUntilFound(find.text('Jeges sín (gyorsító)'));
      expect(find.text('Olvadt sín (lassító)'), findsOneWidget);

      final greenTram = find.text('Zöld (W/S + bal SHIFT)');
      await scrollDownUntilFound(greenTram);
      expect(find.text('4. Villamosok'), findsOneWidget);
      await tester.tap(greenTram);
      await tester.pump();

      expect(controller.selectedPiece, EditorPiece.tramGreen);
    },
  );
}
