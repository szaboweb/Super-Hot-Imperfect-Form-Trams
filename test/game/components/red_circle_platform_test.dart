import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/components/crossover_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/tram_component.dart';
import 'package:super_hot_imperfect_form_trams/input/tram_controls.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_data.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_path.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_switch_system.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_turn.dart';

void main() {
  final level = LevelData.fromJson(
    jsonDecode(
      File('assets/data/levels/example_two_loops.json').readAsStringSync(),
    ) as Map<String, dynamic>,
  );
  final paths = {
    for (final s in level.segments)
      if (s.points.length >= 2) s.id: TrackPath(s.points, name: s.id),
  };
  final turns = [
    for (final data in level.crossovers)
      for (final l in data.links)
        TurntableTurn.build(
          from: paths[l.from]!,
          to: paths[l.to]!,
          center: data.center,
          radius: data.radius,
          movement: data.movement,
        ),
  ];
  final red = level.crossovers.firstWhere((c) => c.id == 'sw_red');

  for (final (from, to) in [
    ('wide_loop', 'tall_loop'),
    ('tall_loop', 'wide_loop'),
  ]) {
    test('sw_red turns a tram from $from to $to', () {
      final path = paths[from]!;
      final start = path.nearest(red.center).along - 40;
      final tram = TramComponent(
        path: path,
        trackDistance: (start + path.length) % path.length,
        speed: 160,
      )..switches = TurntableSwitchSystem(turns);
      expect(tram.requestTurn(), isTrue, reason: 'HIT expected');
      var last = tram.position.clone();
      var maxJump = 0.0;
      for (var i = 0; i < 200 && tram.ride != null; i++) {
        tram.update(0.01);
        maxJump = max(maxJump, (tram.position - last).length);
        last = tram.position.clone();
      }
      expect(tram.ride, isNull);
      expect(maxJump, lessThan(10));
      expect(tram.path.name, to);
      final want = tram.path.headingAt(tram.trackDistance);
      expect(sin(tram.angle - want), closeTo(0, 0.05));
      expect(cos(tram.angle - want), greaterThan(0.99));
    });
  }

  for (final from in ['wide_loop', 'tall_loop']) {
    test('sw_red wins the decision at every offset on the disc ($from)', () {
      final path = paths[from]!;
      final base = path.nearest(red.center).along;
      final system = TurntableSwitchSystem(turns);
      for (var off = -60.0; off <= 60; off += 5) {
        final d = system.decide(
          path: path,
          distance: (base + off + path.length) % path.length,
          speed: 160,
          halfLength: 14,
        );
        final t = d.turn;
        expect(d.isHit, isTrue, reason: 'MISS at ${off}px');
        expect(t!.center, red.center, reason: 'wrong disc at ${off}px');
      }
    });
  }

  for (final data in level.crossovers) {
    test(
      'the light of ${data.id} (${data.shape.name}) shows who turned last',
      () {
        final own = [
          for (final t in turns)
            if (t.center == data.center) t,
        ];
        final path = own.first.from;
        final tram = TramComponent(
          path: path,
          trackDistance: (own.first.fromAlong - 40 + path.length) % path.length,
          speed: 160,
          controls: TramControls.arrows,
        )..switches = TurntableSwitchSystem(turns);
        final crossover = CrossoverComponent(
          data: data,
          turns: own,
          trams: [tram],
        );
        expect(crossover.lastUser, isNull);
        expect(tram.requestTurn(), isTrue);
        tram.update(0.01);
        crossover.update(0.01);
        expect(crossover.lastUser, TramControls.arrows);
      },
    );
  }
}
