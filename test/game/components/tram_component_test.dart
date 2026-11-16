import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/components/tram_component.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_path.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_switch_system.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/turntable_turn.dart';

void main() {
  final path = TrackPath(const [Point(0, 0), Point(0, -500)]);

  test('accelerating tram advances along the path and faces its direction', () {
    final tram = TramComponent(path: path)..throttle = 1;
    tram.update(0.5);
    expect(tram.trackDistance, greaterThan(0));
    expect(tram.position.y, lessThan(0));
    expect(tram.position.x, closeTo(0, 0.001));
    expect(tram.angle, closeTo(0, 0.001));
    expect(tram.speed, lessThanOrEqualTo(TramComponent.maxSpeed));
  });

  test('tram starts exactly on the path at the given distance', () {
    final tram = TramComponent(path: path, trackDistance: 100);
    expect(tram.position.y, closeTo(-100, 0.001));
  });

  test('brakeEfficiency drops linearly with brakeHeat and fades braking', () {
    final coolTram = TramComponent(path: path, trackDistance: 100, speed: 200)
      ..throttle = -1
      ..brakeHeat = 0;
    final hotTram = TramComponent(path: path, trackDistance: 100, speed: 200)
      ..throttle = -1
      ..brakeHeat = 1;

    expect(coolTram.brakeEfficiency, closeTo(1.0, 0.001));
    expect(
      hotTram.brakeEfficiency,
      closeTo(TramComponent.minBrakeEfficiency, 0.001),
    );

    coolTram.update(0.1);
    hotTram.update(0.1);
    expect(hotTram.speed, greaterThan(coolTram.speed));
  });

  test('requestTurn works in reverse gear (speed < 0)', () {
    final east = TrackPath(const [Point(-300, -250), Point(300, -250)]);
    final turn = TurntableTurn.build(
      from: path,
      to: east,
      center: const Point(0, -250),
    );
    final tram = TramComponent(path: path, trackDistance: 270, speed: -120)
      ..switches = TurntableSwitchSystem([turn]);

    expect(tram.requestTurn(), isTrue);
    expect(tram.ride, isNotNull);
  });

  test('markCrashed freezes motion, clears ride, and blocks requestTurn', () {
    final east = TrackPath(const [Point(-300, -250), Point(300, -250)]);
    final turn = TurntableTurn.build(
      from: path,
      to: east,
      center: const Point(0, -250),
    );
    final tram = TramComponent(path: path, trackDistance: 230, speed: 120)
      ..throttle = 1
      ..switches = TurntableSwitchSystem([turn]);

    expect(tram.requestTurn(), isTrue);
    expect(tram.ride, isNotNull);

    tram.markCrashed();
    expect(tram.isCrashed, isTrue);
    expect(tram.speed, 0);
    expect(tram.throttle, 0);
    expect(tram.ride, isNull);
    expect(tram.requestTurn(), isFalse);

    final posBefore = tram.position.clone();
    tram.throttle = 1;
    tram.update(0.2);
    expect(tram.position.distanceTo(posBefore), closeTo(0, 0.001));
    expect(tram.trackDistance, closeTo(230, 0.001));

    final recorder = PictureRecorder();
    tram.render(Canvas(recorder));
    recorder.endRecording().dispose();
  });
}
