import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;

import '../audio/audio_service.dart';
import '../core/game_log.dart';
import 'components/crash_effect_component.dart';
import 'components/headlight_component.dart';
import 'components/hud_component.dart';
import 'components/tram_component.dart';
import 'components/tram_trailer_component.dart';
import 'levels/level_data.dart';
import 'levels/level_loader_system.dart';
import 'levels/level_repository.dart';
import 'systems/crash_system.dart';
import 'systems/score_system.dart';
import 'systems/track_graph.dart';
import 'tram_world_builder.dart';

/// Root Flame game: loads [initialLevel] (or the first asset level) and builds
/// the world layer by layer (see `RenderLayer`): depth, ground, track,
/// entities, canopy, atmosphere + HUD.
class TramGame extends FlameGame with HasKeyboardHandlerComponents {
  TramGame({this.initialLevel, this.audio});

  final LevelData? initialLevel;

  /// Optional sound-effects service triggered by switches, crashes, and goals.
  final AudioService? audio;

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
  late final TramWorldBuilder _worldBuilder;
  final Map<TramComponent, double> _aiCruiseSpeeds = {};
  double _shakeTimer = 0;

  /// Score and crash-goal state for the active level.
  ScoreSystem get scoreSystem => _runtime.scoreSystem;

  /// Camera visible size covering at least [visibleSize] and the loaded level bounds.
  Vector2 get effectiveVisibleSize => Vector2(
    math.max(visibleSize.x, _level.width),
    math.max(visibleSize.y, _level.height),
  );

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
    _worldBuilder = TramWorldBuilder(
      level: _level,
      runtime: _runtime,
      trams: trams,
      aiCruiseSpeeds: _aiCruiseSpeeds,
      world: world,
      audio: audio,
    );
    await world.addAll(_worldBuilder.buildLayers());
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
      final tram = _worldBuilder.createTram(spawn);
      trams.add(tram);
      unawaited(
        world.addAll([
          tram,
          TramTrailerComponent(lead: tram),
          HeadlightComponent(tram: tram),
        ]),
      );
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
    ], occupiedCenters: _worldBuilder.occupiedPlatformCenters());
    for (final e in commands.entries) {
      trams[e.key].throttle = e.value.throttle;
      if (e.value.shouldTurn) {
        trams[e.key].requestTurn(desiredDirection: e.value.desiredDirection);
      }
    }
  }

  void _stepCrashes() {
    final poses = [
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
    ];
    final result = _runtime.crashSystem.step(poses);
    final gateCrashes = _runtime.gateSystem.step(
      poses,
      onAutoClosed: (g) =>
          GameLog.event('switch', '${g.data.id}: closed behind tram'),
    );
    for (final tr in result.transitions) {
      final p = tr.nextPath.positionAt(tr.nextDistance);
      trams[tr.tramIndex]
        ..path = tr.nextPath
        ..trackDistance = tr.nextDistance
        ..position.setValues(p.x, p.y)
        ..angle = tr.nextPath.headingAt(tr.nextDistance);
    }
    for (final event in [...result.crashes, ...gateCrashes]) {
      _recordCrash(event);
    }
  }

  void _recordCrash(CrashEvent event) {
    for (final idx in event.tramIndices) {
      trams[idx].markCrashed(hazard: event.hazard);
    }
    final pending = world.add(
      CrashEffectComponent(
        position: Vector2(event.position.x, event.position.y),
        hazard: event.hazard,
      ),
    );
    if (pending is Future<void>) unawaited(pending);
    unawaited(audio?.playCrash(intoWater: event.hazard == TrackEnd.river));
    _shakeTimer = _shakeDurationSec;
    GameLog.event('crash', event.description);
    if (!_runtime.scoreSystem.record(event)) return;
    goalMetNotifier.value = true;
    unawaited(audio?.playGoalReached());
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
