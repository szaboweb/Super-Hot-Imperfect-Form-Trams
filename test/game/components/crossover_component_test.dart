import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/core/game_log.dart';
import 'package:super_hot_imperfect_form_trams/game/components/crossover_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/tram_component.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/crossover_data.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_path.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_switch_system.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_turn.dart';
import 'package:super_hot_imperfect_form_trams/input/tram_controls.dart';

void main() {
  final north = TrackPath(const [
    Point(0.0, 300.0),
    Point(0.0, -300.0),
  ], name: 'north');
  final east = TrackPath(const [
    Point(-300.0, 0.0),
    Point(300.0, 0.0),
  ], name: 'east');
  final turn = TurntableTurn.build(
    from: north,
    to: east,
    center: const Point(0.0, 0.0),
  );
  const data = CrossoverData(
    id: 'sw',
    x: 0,
    y: 0,
    links: [(from: 'north', to: 'east')],
  );

  TramComponent tramAt(double distance, {TramControls? controls}) =>
      TramComponent(
        path: north,
        trackDistance: distance,
        speed: 160,
        controls: controls,
      )..switches = TurntableSwitchSystem([turn]);

  test(
    'a tram on the disc rides it, turns, and continues on the other loop',
    () {
      final tram = tramAt(240);
      expect(tram.requestTurn(), isTrue);
      for (var i = 0; i < 60 && tram.ride != null; i++) {
        tram.update(0.02);
      }
      expect(tram.ride, isNull);
      expect(identical(tram.path, east), isTrue);
      expect(tram.position.y, closeTo(0, 0.5));
      expect(tram.position.x, greaterThan(70));
      expect(tram.angle, closeTo(pi / 2, 0.02));
    },
  );

  test('a tram that sent no signal drives straight on', () {
    final tram = tramAt(240);
    for (var i = 0; i < 20; i++) {
      tram.update(0.02);
    }
    expect(identical(tram.path, north), isTrue);
    expect(tram.position.x, closeTo(0, 0.001));
  });

  test('the tram\'s own SHIFT signal only works on the disc and is logged', () {
    final lines = <String>[];
    GameLog.sink = lines.add;
    addTearDown(() => GameLog.sink = null);

    final far = tramAt(100, controls: TramControls.arrows);
    expect(far.requestTurn(), isFalse);
    expect(far.ride, isNull);
    expect(lines.single, contains('R-SHIFT'));
    expect(lines.single, contains('MISS'));

    lines.clear();
    final onDisc = tramAt(270, controls: TramControls.wasd);
    expect(onDisc.requestTurn(), isTrue);
    expect(onDisc.ride, isNotNull);
    expect(lines.single, contains('-30.0px from the disc centre'));
    expect(lines.single, contains('HIT, disc turns 90°'));
  });

  test('a signal turns only the tram that sent it', () {
    final sender = tramAt(270, controls: TramControls.wasd);
    final other = tramAt(272, controls: TramControls.arrows);
    expect(sender.requestTurn(), isTrue);
    expect(other.ride, isNull);
  });

  test('SHIFT signals closer than 1/3 s are ignored (spam protection)', () {
    final lines = <String>[];
    GameLog.sink = lines.add;
    addTearDown(() => GameLog.sink = null);
    final tram = tramAt(100, controls: TramControls.wasd);

    expect(tram.requestTurn(), isFalse, reason: 'off the disc: MISS');
    expect(lines.single, endsWith('MISS'));

    tram.trackDistance = 270; // now on the disc, but the cooldown is running
    expect(tram.requestTurn(), isFalse);
    expect(lines.last, contains('ignored'));
    expect(lines.last, contains('cooldown left'));
    expect(tram.ride, isNull);

    tram.update(0.34);
    tram.trackDistance = 270;
    expect(tram.requestTurn(), isTrue, reason: 'cooldown over');
    expect(tram.ride, isNotNull);
  });

  test('a stopped tram cannot signal', () {
    final stopped = TramComponent(path: north, trackDistance: 270, speed: 0)
      ..switches = TurntableSwitchSystem([turn]);
    expect(stopped.requestTurn(), isFalse);
  });

  test(
    'the light remembers who used the disc; the disc swings back to rest',
    () {
      final tram = tramAt(250, controls: TramControls.arrows)..requestTurn();
      final crossover = CrossoverComponent(
        data: data,
        turns: [turn],
        trams: [tram],
      );
      expect(crossover.lastUser, isNull);
      for (var i = 0; i < 12; i++) {
        tram.update(0.02);
        crossover.update(0.02);
      }
      expect(crossover.turntableAngle.abs(), greaterThan(0));
      expect(crossover.lastUser, TramControls.arrows);
      for (var i = 0; i < 80; i++) {
        tram.update(0.02);
        crossover.update(0.02);
      }
      expect(tram.ride, isNull);
      expect(crossover.turntableAngle, closeTo(0, 0.001));
      expect(crossover.lastUser, TramControls.arrows);
    },
  );
}
