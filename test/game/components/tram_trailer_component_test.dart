import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/components/tram_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/tram_trailer_component.dart';
import 'package:super_hot_imperfect_form_trams/game/graphics/render_layer.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_graph.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_path.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_switch_system.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_turn.dart';

void main() {
  test(
    'trailer starts lagPx behind lead and follows along curved TrackPath',
    () {
      final path = TrackPath(const [
        math.Point(0, 0),
        math.Point(0, -120),
        math.Point(120, -120),
      ]);
      final lead = TramComponent(path: path, speed: 160);
      final trailer = TramTrailerComponent(lead: lead);

      expect(trailer.position.x, closeTo(0, 1e-3));
      expect(trailer.position.y, closeTo(TramTrailerComponent.lagPx, 1e-3));
      expect(trailer.priority, RenderLayer.entities.priority - 1);

      for (var i = 0; i < 20; i++) {
        lead.throttle = 0.2;
        lead.update(0.05);
        trailer.update(0.05);
      }
      expect(lead.position.x, greaterThan(10));
      expect(
        lead.position.distanceTo(trailer.position),
        inInclusiveRange(30, TramTrailerComponent.lagPx + 2),
      );
    },
  );

  test(
    'trailer mirrors river plunge priority, scale, and renders all states',
    () {
      final path = TrackPath(const [math.Point(0, 0), math.Point(0, -200)]);
      final lead = TramComponent(path: path, trackDistance: 100, speed: 150);
      final trailer = TramTrailerComponent(lead: lead);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      trailer.render(canvas);

      lead.markCrashed();
      trailer.update(0.1);
      trailer.render(canvas);
      expect(trailer.priority, RenderLayer.entities.priority - 1);

      final riverLead = TramComponent(
        path: path,
        trackDistance: 100,
        speed: 150,
      );
      final riverTrailer = TramTrailerComponent(lead: riverLead);
      riverLead.markCrashed(hazard: TrackEnd.river);
      riverLead.update(0.35);
      riverTrailer.update(0.35);
      riverTrailer.render(canvas);
      recorder.endRecording().dispose();

      expect(riverTrailer.priority, RenderLayer.depth.priority + 4);
      expect(riverTrailer.scale.x, lessThan(1.0));
    },
  );

  test('TramComponent.onTurnMiss fires on miss and not on valid hit', () {
    final ns = TrackPath(const [math.Point(0, 0), math.Point(0, -400)]);
    final ew = TrackPath(const [math.Point(-200, -200), math.Point(200, -200)]);
    final turn = TurntableTurn.build(
      from: ns,
      to: ew,
      center: const math.Point(0, -200),
    );
    var misses = 0;
    var hits = 0;
    final tram = TramComponent(path: ns, trackDistance: 20, speed: 120)
      ..switches = TurntableSwitchSystem([turn])
      ..onTurnHit = (_) {
        hits++;
      }
      ..onTurnMiss = () {
        misses++;
      };

    expect(tram.requestTurn(), isFalse);
    expect(misses, 1);
    expect(hits, 0);

    tram.update(0.4); // clear cooldown
    tram.trackDistance = 190;
    expect(tram.requestTurn(), isTrue);
    expect(misses, 1);
    expect(hits, 1);
  });
}
