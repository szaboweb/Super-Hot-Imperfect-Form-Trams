import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/audio/audio_service.dart';
import 'package:super_hot_imperfect_form_trams/game/components/atmosphere_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/building_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/crossover_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/depth_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/ground_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/hazard_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/headlight_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/overhead_wire_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/signal_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/smoke_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/track_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/tram_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/tram_trailer_component.dart';
import 'package:super_hot_imperfect_form_trams/game/components/turntable_disc_component.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_data.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_loader_system.dart';
import 'package:super_hot_imperfect_form_trams/game/tram_world_builder.dart';

LevelData _sampleLevel() => LevelData.fromJson({
  'id': 'builder_test',
  'bounds': {'width': 1040, 'height': 680},
  'segments': [
    {
      'id': 'ns',
      'end': 'connected',
      'nextSegment': 'ns',
      'points': [
        [0, 200],
        [0, -200],
        [200, -200],
        [200, 200],
        [0, 200],
      ],
    },
    {
      'id': 'ew',
      'end': 'river',
      'points': [
        [-200, 0],
        [200, 0],
      ],
    },
  ],
  'crossovers': [
    {
      'id': 'sw_center',
      'platformShape': 'circle',
      'x': 0,
      'y': 0,
      'links': [
        {'from': 'ns', 'to': 'ew'},
        {'from': 'ew', 'to': 'ns'},
      ],
    },
  ],
  'props': [
    {
      'type': 'channel',
      'x': 120,
      'y': 0,
      'width': 60,
      'height': 180,
      'rotation': 0,
      'state': 'green',
    },
    {
      'type': 'signal',
      'x': -40,
      'y': -40,
      'width': 16,
      'height': 16,
      'rotation': 90,
      'state': 'red',
    },
    {
      'type': 'building',
      'x': -140,
      'y': -120,
      'width': 80,
      'height': 60,
      'rotation': 0,
      'state': 'green',
    },
  ],
  'spawns': [
    {
      'segment': 'ns',
      'time': 0,
      'speed': 120,
      'startDistance': 140,
      'controls': 'wasd',
    },
    {'segment': 'ew', 'time': 0, 'speed': 90, 'startDistance': 40},
    {'segment': 'ns', 'time': 2.0, 'speed': 100, 'startDistance': 20},
  ],
  'goal': {'crashes': 1},
});

void main() {
  test(
    'buildLayers assembles layer components and registers initial trams',
    () {
      final level = _sampleLevel();
      final runtime = const LevelLoaderSystem().load(level);
      final trams = <TramComponent>[];
      final aiCruiseSpeeds = <TramComponent, double>{};
      final builder = TramWorldBuilder(
        level: level,
        runtime: runtime,
        trams: trams,
        aiCruiseSpeeds: aiCruiseSpeeds,
      );

      final layers = builder.buildLayers();

      expect(layers.first, isA<DepthComponent>());
      expect(layers.whereType<GroundComponent>(), hasLength(1));
      // 2 segment TrackComponents + 1 TurntableRailComponent (extends TrackComponent).
      expect(layers.whereType<TrackComponent>(), hasLength(3));
      expect(layers.whereType<HazardComponent>(), isNotEmpty);
      expect(layers.whereType<SignalComponent>(), hasLength(1));
      expect(layers.whereType<CrossoverComponent>(), hasLength(1));
      expect(layers.whereType<TurntableDiscComponent>(), hasLength(1));
      expect(layers.whereType<BuildingComponent>(), hasLength(1));
      expect(layers.whereType<OverheadWireComponent>(), hasLength(2));
      expect(layers.whereType<AtmosphereComponent>(), hasLength(1));
      expect(layers.whereType<SmokeComponent>(), hasLength(1));
      expect(layers.whereType<TramComponent>(), hasLength(2));
      expect(layers.whereType<TramTrailerComponent>(), hasLength(2));
      expect(layers.whereType<HeadlightComponent>(), hasLength(2));

      expect(trams, hasLength(2));
      expect(aiCruiseSpeeds.length, 1);
      expect(aiCruiseSpeeds[trams[1]], 90);
      expect(aiCruiseSpeeds.containsKey(trams[0]), isFalse);
    },
  );

  test('createTram throws StateError when segment geometry is missing', () {
    final level = _sampleLevel();
    final runtime = const LevelLoaderSystem().load(level);
    final builder = TramWorldBuilder(
      level: level,
      runtime: runtime,
      trams: <TramComponent>[],
      aiCruiseSpeeds: <TramComponent, double>{},
    );

    expect(
      () => builder.createTram(
        const SpawnData(segment: 'missing', time: 0, speed: 80),
      ),
      throwsStateError,
    );
  });

  test('createTram wires turn audio callbacks and occupied centers', () async {
    final level = _sampleLevel();
    final runtime = const LevelLoaderSystem().load(level);
    final trams = <TramComponent>[];
    final played = <String>[];
    final audio = AudioService(
      backend: (file, volume) async => played.add(file),
      minRepeatIntervalMs: 0,
    );
    addTearDown(audio.dispose);

    final builder = TramWorldBuilder(
      level: level,
      runtime: runtime,
      trams: trams,
      aiCruiseSpeeds: <TramComponent, double>{},
      world: World(),
      audio: audio,
    );
    builder.buildLayers();

    trams[0].onTurnHit?.call(Vector2.zero());
    trams[0].onTurnMiss?.call();
    await Future<void>.delayed(Duration.zero);

    expect(played, ['sfx/sfx_switch_01.wav', 'sfx/sfx_miss_01.wav']);
    expect(builder.occupiedPlatformCenters(), isEmpty);
    expect(trams[0].requestTurn(), isTrue);
    expect(builder.occupiedPlatformCenters(), hasLength(1));
  });
}
