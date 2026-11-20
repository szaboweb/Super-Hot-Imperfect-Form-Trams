import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../audio/audio_service.dart';
import 'components/atmosphere_component.dart';
import 'components/building_component.dart';
import 'components/crossover_component.dart';
import 'components/depth_component.dart';
import 'components/gate_component.dart';
import 'components/ground_component.dart';
import 'components/hazard_component.dart';
import 'components/headlight_component.dart';
import 'components/overhead_wire_component.dart';
import 'components/signal_component.dart';
import 'components/smoke_component.dart';
import 'components/spark_effect_component.dart';
import 'components/track_component.dart';
import 'components/track_zone_component.dart';
import 'components/tram_component.dart';
import 'components/tram_trailer_component.dart';
import 'components/turntable_disc_component.dart';
import 'levels/level_data.dart';
import 'levels/level_loader_system.dart';
import 'levels/prop_data.dart';
import 'systems/track_path.dart';

/// Builds Flame world layers and [TramComponent]s for a loaded level.
class TramWorldBuilder {
  /// Creates a world builder wiring [level] and [runtime] layers into [trams].
  TramWorldBuilder({
    required this.level,
    required this.runtime,
    required this.trams,
    required this.aiCruiseSpeeds,
    this.world,
    this.audio,
  });

  /// Loaded level definition supplying bounds, props, and spawn settings.
  final LevelData level;

  /// Pure-Dart runtime systems and track geometry assembled for [level].
  final LoadedLevelRuntime runtime;

  /// Mutable tram list populated during world assembly and timed spawns.
  final List<TramComponent> trams;

  /// Cruise speed registry populated for AI-driven (`GÉPI`) trams.
  final Map<TramComponent, double> aiCruiseSpeeds;

  /// Optional Flame [World] receiving one-shot spark effects on `SHIFT` hits.
  final World? world;

  /// Optional sound-effects service triggered when trams send `SHIFT` signals.
  final AudioService? audio;

  late final GroundComponent _ground = _createGround();

  Vector2 get _bounds => Vector2(level.width, level.height);

  /// Ground layer component shared with trams for tire skid marks.
  GroundComponent get ground => _ground;

  /// Builds initial trams and returns all world components ordered by layer.
  List<Component> buildLayers() {
    final paths = runtime.paths.values.toList();
    trams.clear();
    aiCruiseSpeeds.clear();
    for (final spawn in runtime.spawnSystem.advance(0)) {
      trams.add(createTram(spawn));
    }
    return [
      ..._groundLayers(),
      ..._trackLayers(paths),
      ..._entityLayers(),
      ..._canopyLayers(paths),
      ..._atmosphereLayers(),
    ];
  }

  /// Creates one configured [TramComponent] for [spawn] and tracks AI speed.
  TramComponent createTram(SpawnData spawn) {
    final path = runtime.paths[spawn.segment];
    if (path == null) {
      throw StateError('Spawn segment "${spawn.segment}" has no geometry');
    }
    final tram =
        TramComponent(
            path: path,
            speed: spawn.speed,
            controls: spawn.controls,
            trackDistance: spawn.startDistance,
            color: Color(spawn.color),
          )
          ..switches = runtime.switches
          ..gates = runtime.gateSystem
          ..zones = runtime.zoneSystem
          ..occupiedPlatformCenters = occupiedPlatformCenters
          ..onSkid = _ground.addSkidMark
          ..onTurnHit = (p) {
            final pending = world?.add(
              SparkEffectComponent(position: p.clone()),
            );
            if (pending is Future<void>) unawaited(pending);
            unawaited(audio?.playSwitchHit());
          }
          ..onTurnMiss = () => unawaited(audio?.playSwitchMiss());
    if (spawn.controls == null && spawn.speed != 0) {
      aiCruiseSpeeds[tram] = spawn.speed;
    }
    return tram;
  }

  /// Platform centres currently occupied by any tram riding a crossover.
  Iterable<math.Point<double>> occupiedPlatformCenters() => [
    for (final other in trams)
      if (other.ride case final ride?) ride.turn.center,
  ];

  GroundComponent _createGround() => GroundComponent(
    bounds: _bounds,
    channels: [
      for (final p in _propsOf(PropType.channel))
        Rect.fromCenter(
          center: Offset(p.x, p.y),
          width: p.width,
          height: p.height,
        ),
    ],
    paths: runtime.paths.values.toList(),
  );

  Iterable<PropData> _propsOf(PropType type) =>
      level.props.where((p) => p.type == type);

  List<Component> _groundLayers() => [DepthComponent(), _ground];

  List<Component> _trackLayers(List<TrackPath> paths) => [
    for (final path in paths) TrackComponent(path: path),
    for (final z in runtime.zoneSystem.zones) TrackZoneComponent(zone: z),
    for (final h in runtime.hazards) _hazardComponent(h),
    for (final g in runtime.gateSystem.gates) GateComponent(gate: g),
    for (final p in _propsOf(PropType.signal)) _signalComponent(p),
    for (final c in runtime.crossovers) ..._crossoverComponents(c),
  ];

  List<Component> _entityLayers() => [
    for (final tram in trams) TramTrailerComponent(lead: tram),
    ...trams,
  ];

  List<Component> _canopyLayers(List<TrackPath> paths) => [
    for (final p in _propsOf(PropType.building)) _buildingComponent(p),
    for (final path in paths) OverheadWireComponent(path: path),
  ];

  List<Component> _atmosphereLayers() => [
    AtmosphereComponent(bounds: _bounds),
    SmokeComponent(trams: trams),
    for (final tram in trams) HeadlightComponent(tram: tram),
  ];

  HazardComponent _hazardComponent(HazardPlacement h) => HazardComponent(
    kind: h.kind,
    position: Vector2(h.position.x, h.position.y),
    headingRad: h.headingRad,
  );

  SignalComponent _signalComponent(PropData p) => SignalComponent(
    position: Vector2(p.x, p.y),
    rotationDeg: p.rotationDeg,
    green: p.state != 'red',
  );

  BuildingComponent _buildingComponent(PropData p) => BuildingComponent(
    position: Vector2(p.x, p.y),
    size: Vector2(p.width, p.height),
    angle: p.rotationDeg * math.pi / 180,
  );

  List<Component> _crossoverComponents(LoadedCrossover c) {
    final cx = CrossoverComponent(data: c.data, turns: c.turns, trams: trams);
    return [cx, TurntableDiscComponent(crossover: cx), cx.buildPlatformRail()];
  }
}
