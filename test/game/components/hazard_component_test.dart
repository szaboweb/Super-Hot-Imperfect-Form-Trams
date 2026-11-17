import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/components/crash_effect_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/hazard_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/smoke_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/spark_effect_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/tram_component.dart';
import 'package:super_hot_imperfect_form_trams/game/graphics/render_layer.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_graph.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_path.dart';

void _renderOnce(void Function(Canvas canvas) draw) {
  final recorder = PictureRecorder();
  draw(Canvas(recorder));
  recorder.endRecording().dispose();
}

void main() {
  test(
    'HazardComponent renders deadEnd, construction, and river across updates',
    () {
      for (final kind in const [
        TrackEnd.deadEnd,
        TrackEnd.construction,
        TrackEnd.river,
      ]) {
        final hazard = HazardComponent(
          kind: kind,
          position: Vector2(40, -20),
          headingRad: 0.4,
        );
        expect(hazard.priority, RenderLayer.track.priority + 4);
        _renderOnce(hazard.render);
        hazard.update(0.5);
        _renderOnce(hazard.render);
      }
    },
  );

  testWithFlameGame(
    'SparkEffectComponent and CrashEffectComponent auto-remove after duration',
    (game) async {
      final spark = SparkEffectComponent(position: Vector2(10, 20));
      final crashSurface = CrashEffectComponent(position: Vector2.zero());
      final crashRiver = CrashEffectComponent(
        position: Vector2(30, 30),
        hazard: TrackEnd.river,
      );
      await game.ensureAddAll([spark, crashSurface, crashRiver]);

      expect(spark.isMounted, isTrue);
      expect(crashSurface.isMounted, isTrue);
      expect(crashRiver.isMounted, isTrue);

      game.update(0.15);
      _renderOnce(spark.render);
      _renderOnce(crashSurface.render);
      _renderOnce(crashRiver.render);

      game.update(0.2);
      game.update(0);
      expect(spark.isMounted, isFalse);
      expect(crashSurface.isMounted, isTrue);

      game.update(0.2);
      game.update(0);
      expect(crashSurface.isMounted, isFalse);
      expect(crashRiver.isMounted, isFalse);
    },
  );

  test(
    'SmokeComponent caps puffs at maxPuffs and skips sunken river trams',
    () {
      final path = TrackPath(const [Point(0, 0), Point(0, -300)]);
      final sunkenTram = TramComponent(path: path)
        ..isCrashed = true
        ..priority = RenderLayer.depth.priority + 5;
      final sunkenSmoke = SmokeComponent(trams: [sunkenTram]);
      sunkenSmoke.update(0.3);
      expect(sunkenSmoke.puffCount, 0);

      final hotTram = TramComponent(path: path)..brakeHeat = 0.9;
      final wreckTram = TramComponent(path: path)..isCrashed = true;
      final smoke = SmokeComponent(trams: [hotTram, wreckTram]);
      for (var i = 0; i < 80; i++) {
        smoke.update(0.05);
      }
      expect(smoke.puffCount, greaterThan(0));
      expect(smoke.puffCount, lessThanOrEqualTo(SmokeComponent.maxPuffs));
      _renderOnce(smoke.render);
    },
  );
}
