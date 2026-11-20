import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

import '../core/game_log.dart';

/// Backend callback that plays an audio asset relative to `assets/audio/`.
typedef AudioPlayBackend = Future<void> Function(String file, double volume);

/// Cross-cutting sound-effects service with mute control and headless test safety.
class AudioService {
  /// Creates an [AudioService] with optional custom [backend] and [clock] for tests.
  AudioService({
    AudioPlayBackend? backend,
    DateTime Function()? clock,
    this.minRepeatIntervalMs = 110,
  }) : _backend = backend ?? _defaultBackend,
       _clock = clock ?? DateTime.now;

  static const String _switchHitFile = 'sfx/sfx_switch_01.wav';
  static const String _switchMissFile = 'sfx/sfx_miss_01.wav';
  static const String _crashFile = 'sfx/sfx_crash_01.wav';
  static const String _splashFile = 'sfx/sfx_splash_01.wav';
  static const String _goalFile = 'sfx/sfx_goal_01.wav';

  final AudioPlayBackend _backend;
  final DateTime Function() _clock;
  final Map<String, DateTime> _lastPlayedAt = {};

  /// Minimum interval in milliseconds before the same SFX clip can re-trigger.
  final int minRepeatIntervalMs;

  /// Notifies UI listeners whether game sound effects are muted.
  final ValueNotifier<bool> isMuted = ValueNotifier<bool>(false);

  static Future<void> _defaultBackend(String file, double volume) async {
    await FlameAudio.play(file, volume: volume);
  }

  /// Flips [isMuted] and returns the updated mute state.
  bool toggleMute() {
    isMuted.value = !isMuted.value;
    return isMuted.value;
  }

  /// Plays the metallic rail clack when a `SHIFT` switch boards a platform.
  Future<void> playSwitchHit() => _play(_switchHitFile, 0.75);

  /// Plays the muted relay click when a `SHIFT` signal misses or is busy.
  Future<void> playSwitchMiss() => _play(_switchMissFile, 0.45);

  /// Plays either the water plunge splash ([intoWater]) or the metallic crash crunch.
  Future<void> playCrash({required bool intoWater}) =>
      _play(intoWater ? _splashFile : _crashFile, 0.9);

  /// Plays the dual-strike tram bell and chord when the crash goal is reached.
  Future<void> playGoalReached() => _play(_goalFile, 0.85);

  /// Releases resources held by [isMuted].
  void dispose() {
    isMuted.dispose();
  }

  Future<void> _play(String file, double volume) async {
    if (isMuted.value) return;
    final now = _clock();
    final previous = _lastPlayedAt[file];
    if (previous != null &&
        now.difference(previous).inMilliseconds < minRepeatIntervalMs) {
      return;
    }
    _lastPlayedAt[file] = now;
    try {
      await _backend(file, volume);
    } on Object catch (error) {
      GameLog.event('audio', 'Playback skipped ($file): $error');
    }
  }
}
