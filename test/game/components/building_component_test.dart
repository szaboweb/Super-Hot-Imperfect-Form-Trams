import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/components/building_component.dart';
import 'package:super_hot_imperfect_form_trams/game/graphics/render_layer.dart';

void main() {
  test('BuildingComponent renders 2.5D fallback walls when unmounted', () {
    final building = BuildingComponent(
      position: Vector2(0, 0),
      size: Vector2(120, 80),
    );
    expect(building.priority, RenderLayer.canopy.priority);

    final recorder = PictureRecorder();
    building.render(Canvas(recorder));
    recorder.endRecording().dispose();
  });

  testWidgets(
    'BuildingComponent renders camera-parallax facades inside FlameGame',
    (tester) async {
      final game = FlameGame();
      final northEast = BuildingComponent(
        position: Vector2(280, -160),
        size: Vector2(130, 100),
        angle: math.pi / 12,
      );
      final southWest = BuildingComponent(
        position: Vector2(-260, 180),
        size: Vector2(140, 90),
      );

      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await game.world.addAll([northEast, southWest]);
      game.camera.viewfinder.position = Vector2(40, -30);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(northEast.isMounted, isTrue);
      expect(southWest.isMounted, isTrue);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      northEast.render(canvas);
      southWest.render(canvas);
      recorder.endRecording().dispose();
    },
  );
}
