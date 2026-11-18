import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/tram_pose_trail.dart';

void main() {
  test('reset seeds a straight tail behind start along any heading', () {
    final northTrail = TramPoseTrail()..reset(const math.Point(10, 20), 0);
    final northSample = northTrail.sampleBehind(44);
    expect(northSample.position.x, closeTo(10, 1e-6));
    expect(northSample.position.y, closeTo(64, 1e-6));
    expect(northSample.heading, closeTo(0, 1e-6));

    final eastTrail = TramPoseTrail()
      ..reset(const math.Point(50, -30), math.pi / 2);
    final eastSample = eastTrail.sampleBehind(44);
    expect(eastSample.position.x, closeTo(6, 1e-6));
    expect(eastSample.position.y, closeTo(-30, 1e-6));
    expect(eastSample.heading, closeTo(math.pi / 2, 1e-6));
  });

  test('record tracks a 90-degree corner accurately by arc length', () {
    final trail = TramPoseTrail(minStepPx: 2)..reset(const math.Point(0, 0), 0);
    for (var y = -10.0; y >= -80.0; y -= 10) {
      trail.record(math.Point(0, y), 0);
    }
    for (var x = 10.0; x <= 30.0; x += 10) {
      trail.record(math.Point(x, -80), math.pi / 2);
    }

    // Total after corner = 30 px East, so 44 px behind sits 14 px before corner at (0, -66).
    final behind = trail.sampleBehind(44);
    expect(behind.position.x, closeTo(0, 1e-6));
    expect(behind.position.y, closeTo(-66, 1e-6));
    expect(behind.heading, closeTo(0, 1e-6));
  });

  test('sampleBehind interpolates heading across +/-pi via shortest arc', () {
    final trail = TramPoseTrail(minStepPx: 2)
      ..reset(const math.Point(0, 0), 0.92 * math.pi)
      ..record(const math.Point(0, 20), -0.92 * math.pi);

    final mid = trail.sampleBehind(10);
    expect(mid.heading.abs(), greaterThan(0.9 * math.pi));
  });

  test(
    'history trims older samples beyond maxHistoryPx and ignores micro-steps',
    () {
      final trail = TramPoseTrail(maxHistoryPx: 100, minStepPx: 3)
        ..reset(const math.Point(0, 0), 0)
        ..record(const math.Point(0, -1), 0); // ignored (< minStepPx)
      expect(trail.sampleBehind(40).position.y, closeTo(40, 1e-6));

      for (var i = 1; i <= 60; i++) {
        trail.record(math.Point(0, -i * 5.0), 0);
      }
      final maxBehind = trail.sampleBehind(100);
      expect(maxBehind.position.x, closeTo(0, 1e-6));
      expect(maxBehind.position.y, closeTo(-200, 1e-6));
    },
  );
}
