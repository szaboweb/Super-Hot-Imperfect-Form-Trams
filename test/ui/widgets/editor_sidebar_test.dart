import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_controller.dart';
import 'package:super_hot_imperfect_form_trams/game/editor/editor_piece.dart';
import 'package:super_hot_imperfect_form_trams/ui/widgets/editor_sidebar.dart';

void main() {
  testWidgets(
    'displays all 4 shelves, 6 new pieces, scrolls and selects tramGreen',
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
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(of: scrollFinder, matching: find.byType(Scrollable))
            .first,
      );
      expect(scrollable.position.pixels, 0.0);

      await tester.drag(scrollFinder, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, greaterThan(0.0));

      expect(find.text('2. Váltók'), findsOneWidget);
      expect(find.text('Y váltó (kisív)'), findsOneWidget);
      expect(find.text('Sorompó'), findsOneWidget);

      await tester.drag(scrollFinder, const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('3. Speciális'), findsOneWidget);
      expect(find.text('Jeges sín (gyorsító)'), findsOneWidget);
      expect(find.text('Olvadt sín (lassító)'), findsOneWidget);

      await tester.drag(scrollFinder, const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('4. Villamosok'), findsOneWidget);
      final greenTram = find.text('Zöld (W/S + bal SHIFT)');
      expect(greenTram, findsOneWidget);
      await tester.tap(greenTram);
      await tester.pump();

      expect(controller.selectedPiece, EditorPiece.tramGreen);
    },
  );
}
