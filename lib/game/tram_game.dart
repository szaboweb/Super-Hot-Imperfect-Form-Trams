import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;

import '../core/game_log.dart';
import 'components/atmosphere_component.dart';
import 'components/building_component.dart';
import 'components/crash_effect_component.dart';
import 'components/crossover_component.dart';
import 'components/depth_component.dart';
import 'components/ground_component.dart';
import 'components/hazard_component.dart';
import 'components/headlight_component.dart';
import 'components/hud_component.dart';
import 'components/overhead_wire_component.dart';
import 'components/signal_component.dart';
import 'components/smoke_component.dart';
import 'components/spark_effect_component.dart';
import 'components/track_component.dart';
import 'components/tram_component.dart';
import 'components/turntable_disc_component.dart';
import 'levels/level_data.dart';
import 'levels/level_loader_system.dart';
import 'levels/level_repository.dart';
import 'levels/prop_data.dart';
import 'systems/crash_system.dart';
import 'systems/score_system.dart';

/// Root Flame game: loads [initialLevel] (or the first asset level) and builds
/// the world layer by layer (see `RenderLayer`): depth, ground, track,
/// entities, canopy, atmosphere + HUD.
class TramGame extends FlameGame with HasKeyboardHandlerComponents {
  TramGame({this.initialLevel});

  final LevelData? initialLevel;

  /// All trams of the loaded level, in spawn order.
  final List<TramComponent> trams = [];

  /// Notifies UI widgets when the level crash goal is first satisfied.
  final ValueNotifier<bool> goalMetNotifier = ValueNotifier<bool>(false);

  /// Minimum viewport extent in world px so small levels are not zoomed too close.
  static final Vector2 visibleSize = Vector2(1040, 680);

  static const double _shakeDurationSec = 0.28;
  static const double _shakeMaxAmplitudePx = 6.0;

  late final LevelData _level;
  late final LoadedLevelRuntime _runtime;
  late final GroundComponent _ground;
  final Map<TramComponent, double> _aiCruiseSpeeds = {};
  double _shakeTimer = 0;

  /// Score and crash-goal state for the active level.
  ScoreSystem get scoreSystem => _runtime.scoreSystem;

  /// Camera visible size covering at least [visibleSize] and the loaded level bounds.
  Vector2 get effectiveVisibleSize => Vector2(
    math.max(visibleSize.x, _level.width),
    math.max(visibleSize.y, _level.height),
  );

  Vector2 get _bounds => Vector2(_level.width, _level.height);

  @override
  Color backgroundColor() => const Color(0xFF05080F);

  @override
  Future<void> onLoad() async {
    _level = initialLevel ?? (await LevelRepository().loadAll()).first;
    GameLog.event(
      'level',
      '${_level.id}: ${_level.spawns.length} trams, '
          '${_level.crossovers.length} crossovers',
    );
    _runtime = const LevelLoaderSystem().load(_level);
    await _buildWorldLayers();
    await camera.viewport.add(
      HudComponent(
        trams: trams,
        paths: _runtime.paths.values.toList(),
        score: _runtime.scoreSystem,
      ),
    );
    camera.viewfinder
      ..visibleGameSize = effectiveVisibleSize
      ..position = Vector2.zero();
  }

  @override
  void onRemove() {
    goalMetNotifier.dispose();
    super.onRemove();
  }

  Future<void> _buildWorldLayers() async {
    final paths = _runtime.paths.values.toList();
    _ground = GroundComponent(
      bounds: _bounds,
      channels: [
        for (final p in _level.props.where((p) => p.type == PropType.channel))
          Rect.fromCenter(
            center: Offset(p.x, p.y),
            width: p.width,
            height: p.height,
          ),
      ],
      paths: paths,
    );
    trams.clear();
    _aiCruiseSpeeds.clear();
    for (final spawn in _runtime.spawnSystem.advance(0)) {
      trams.add(_createTram(spawn));
    }
    await world.addAll([
      DepthComponent(),
      _ground,
      for (final path in paths) TrackComponent(path: path),
      for (final h in _runtime.hazards)
        HazardComponent(
          kind: h.kind,
          position: Vector2(h.position.x, h.position.y),
          headingRad: h.headingRad,
        ),
      for (final p in _level.props.where((p) => p.type == PropType.signal))
        SignalComponent(
          position: Vector2(p.x, p.y),
          rotationDeg: p.rotationDeg,
          green: p.state != 'red',
        ),
      ...trams,
      for (final c in _runtime.crossovers) ..._crossoverComponents(c),
      for (final p in _level.props.where((p) => p.type == PropType.building))
        BuildingComponent(
          position: Vector2(p.x, p.y),
          size: Vector2(p.width, p.height),
          angle: p.rotationDeg * math.pi / 180,
        ),
      for (final path in paths) OverheadWireComponent(path: path),
      AtmosphereComponent(bounds: _bounds),
      SmokeComponent(trams: trams),
      for (final tram in trams) HeadlightComponent(tram: tram),
    ]);
  }

  List<Component> _crossoverComponents(LoadedCrossover c) {
    final cx = CrossoverComponent(data: c.data, turns: c.turns, trams: trams);
    return [cx, TurntableDiscComponent(crossover: cx), cx.buildPlatformRail()];
  }

  TramComponent _createTram(SpawnData spawn) {
    final path = _runtime.paths[spawn.segment];
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
          ..switches = _runtime.switches
          ..occupiedPlatformCenters = _occupiedPlatformCenters
          ..onSkid = _ground.addSkidMark
          ..onTurnHit = (p) =>
              world.add(SparkEffectComponent(position: p.clone()));
    if (spawn.controls == null && spawn.speed != 0) {
      _aiCruiseSpeeds[tram] = spawn.speed;
    }
    return tram;
  }

  Iterable<math.Point<double>> _occupiedPlatformCenters() => [
    for (final other in trams)
      if (other.ride != null) other.ride!.turn.center,
  ];

  @override
  void update(double dt) {
    if (_shakeTimer > 0) _shakeTimer = math.max(0, _shakeTimer - dt);
    _stepAi(dt);
    super.update(dt);
    _spawnDueTrams(dt);
    if (trams.isNotEmpty) _stepCrashes();
    _updateCameraShake();
  }

  void _spawnDueTrams(double dt) {
    for (final spawn in _runtime.spawnSystem.advance(dt)) {
      final tram = _createTram(spawn);
      trams.add(tram);
      world.addAll([tram, HeadlightComponent(tram: tram)]);
      GameLog.event(
        'tram',
        '${tram.label} spawned at '
            't=${_runtime.spawnSystem.elapsedSeconds.toStringAsFixed(2)}s',
      );
    }
  }

  void _stepAi(double dt) {
    if (_aiCruiseSpeeds.isEmpty) return;
    final commands = _runtime.aiSystem.step(dt, [
      for (final (i, t) in trams.indexed)
        (
          index: i,
          path: t.path,
          trackDistance: t.trackDistance,
          speed: t.speed,
          cruiseSpeed: _aiCruiseSpeeds[t] ?? 0,
          isPlayerControlled: t.controls != null,
          isRidingTurntable: t.ride != null,
          isCrashed: t.isCrashed,
          position: math.Point(t.position.x, t.position.y),
        ),
    ], occupiedCenters: _occupiedPlatformCenters());
    for (final e in commands.entries) {
      trams[e.key].throttle = e.value.throttle;
      if (e.value.shouldTurn) {
        trams[e.key].requestTurn(desiredDirection: e.value.desiredDirection);
      }
    }
  }

  void _stepCrashes() {
    final result = _runtime.crashSystem.step([
      for (final (i, t) in trams.indexed)
        (
          index: i,
          label: t.label,
          segmentId: t.path.name,
          trackDistance: t.trackDistance,
          speed: t.speed,
          position: math.Point(t.position.x, t.position.y),
          heading: t.angle,
          isRidingTurntable: t.ride != null,
          isCrashed: t.isCrashed,
        ),
    ]);
    for (final tr in result.transitions) {
      final p = tr.nextPath.positionAt(tr.nextDistance);
      trams[tr.tramIndex]
        ..path = tr.nextPath
        ..trackDistance = tr.nextDistance
        ..position.setValues(p.x, p.y)
        ..angle = tr.nextPath.headingAt(tr.nextDistance);
    }
    for (final event in result.crashes) {
      _recordCrash(event);
    }
  }

  void _recordCrash(CrashEvent event) {
    for (final idx in event.tramIndices) {
      trams[idx].markCrashed(hazard: event.hazard);
    }
    world.add(
      CrashEffectComponent(
        position: Vector2(event.position.x, event.position.y),
        hazard: event.hazard,
      ),
    );
    _shakeTimer = _shakeDurationSec;
    GameLog.event('crash', event.description);
    if (!_runtime.scoreSystem.record(event)) return;
    goalMetNotifier.value = true;
    GameLog.event(
      'level',
      'Goal reached: ${_runtime.scoreSystem.crashCount}/'
          '${_runtime.scoreSystem.crashGoal} crashes',
    );
  }

  void _updateCameraShake() {
    if (_shakeTimer <= 0) {
      camera.viewfinder.position = Vector2.zero();
      return;
    }
    final t = _shakeDurationSec - _shakeTimer + 0.017;
    final amp = _shakeMaxAmplitudePx * (_shakeTimer / _shakeDurationSec);
    camera.viewfinder.position = Vector2(
      math.sin(t * 55) * amp,
      math.cos(t * 43) * amp,
    );
  }
}
