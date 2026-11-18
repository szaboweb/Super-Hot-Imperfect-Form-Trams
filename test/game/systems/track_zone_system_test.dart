import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/track_zone_data.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_graph.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_path.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_zone_system.dart';

void main() {
  final segments = {
    'main': const TrackSegment(
      id: 'main',
      points: [math.Point(0.0, 0.0), math.Point(400.0, 0.0)],
    ),
  };

  group('TrackZoneData.validate', () {
    test('accepts valid on-track ice and melted zones', () {
      const ice = TrackZoneData(kind: TrackZoneKind.ice, x: 100, y: 2);
      const melted = TrackZoneData(
        kind: TrackZoneKind.melted,
        x: 300,
        y: -4,
        radius: 28,
      );

      expect(ice.validate(segments), isEmpty);
      expect(melted.validate(segments), isEmpty);
    });

    test('rejects off-track zones and non-positive radii', () {
      const offTrack = TrackZoneData(kind: TrackZoneKind.ice, x: 100, y: 12);
      const zeroRadius = TrackZoneData(
        kind: TrackZoneKind.melted,
        x: 100,
        y: 0,
        radius: 0,
      );
      const negativeRadius = TrackZoneData(
        kind: TrackZoneKind.ice,
        x: 100,
        y: 0,
        radius: -8,
      );

      expect(offTrack.validate(segments), isNotEmpty);
      expect(zeroRadius.validate(segments), isNotEmpty);
      expect(negativeRadius.validate(segments), isNotEmpty);
    });
  });

  group('TrackZoneSystem.effectAt', () {
    late TrackZoneSystem system;

    setUp(() {
      final path = TrackPath(segments['main']!.points, name: 'main');
      system = TrackZoneSystem(
        zones: const [
          TrackZoneData(kind: TrackZoneKind.ice, x: 100, y: 0, radius: 32),
          TrackZoneData(kind: TrackZoneKind.melted, x: 300, y: 0, radius: 32),
        ],
        paths: {'main': path},
      );
    });

    test(
      'ice boosts acceleration, top speed, and glide while reducing brake',
      () {
        final effect = system.effectAt(const math.Point(100.0, 0.0));
        expect(effect.kind, TrackZoneKind.ice);
        expect(effect.boostAccel, greaterThan(0));
        expect(effect.maxSpeedMultiplier, greaterThan(1.0));
        expect(effect.dragPerSec, greaterThan(0.8));
        expect(effect.brakeMultiplier, lessThan(1.0));
      },
    );

    test(
      'melted slows acceleration, caps speed, and increases viscous drag',
      () {
        final effect = system.effectAt(const math.Point(300.0, 0.0));
        expect(effect.kind, TrackZoneKind.melted);
        expect(effect.boostAccel, lessThan(0));
        expect(effect.maxSpeedMultiplier, lessThan(1.0));
        expect(effect.dragPerSec, lessThan(0.8));
      },
    );

    test('outside any zone radius returns neutralEffect', () {
      expect(
        system.effectAt(const math.Point(200.0, 0.0)),
        TrackZoneSystem.neutralEffect,
      );
      expect(
        system.effectAt(const math.Point(132.1, 0.0)),
        TrackZoneSystem.neutralEffect,
      );
    });
  });
}
