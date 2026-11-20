import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/audio/audio_service.dart';
import 'package:super_hot_imperfect_form_trams/core/game_log.dart';

void main() {
  test('semantic play methods route expected SFX files and volumes', () async {
    final calls = <({String file, double volume})>[];
    var now = DateTime.utc(2026, 11, 17, 12);
    final service = AudioService(
      backend: (file, volume) async => calls.add((file: file, volume: volume)),
      clock: () => now,
    );
    addTearDown(service.dispose);

    await service.playSwitchHit();
    await service.playSwitchMiss();
    await service.playCrash(intoWater: false);
    await service.playCrash(intoWater: true);
    await service.playGoalReached();

    expect(calls, [
      (file: 'sfx/sfx_switch_01.wav', volume: 0.75),
      (file: 'sfx/sfx_miss_01.wav', volume: 0.45),
      (file: 'sfx/sfx_crash_01.wav', volume: 0.9),
      (file: 'sfx/sfx_splash_01.wav', volume: 0.9),
      (file: 'sfx/sfx_goal_01.wav', volume: 0.85),
    ]);
  });

  test('toggleMute suppresses playback until unmuted', () async {
    final calls = <String>[];
    var now = DateTime.utc(2026, 11, 17, 12);
    final service = AudioService(
      backend: (file, _) async => calls.add(file),
      clock: () => now,
    );
    addTearDown(service.dispose);

    expect(service.toggleMute(), isTrue);
    expect(service.isMuted.value, isTrue);
    await service.playSwitchHit();
    expect(calls, isEmpty);

    expect(service.toggleMute(), isFalse);
    now = now.add(const Duration(milliseconds: 200));
    await service.playSwitchHit();
    expect(calls, ['sfx/sfx_switch_01.wav']);
  });

  test(
    'minRepeatIntervalMs deduplicates rapid identical SFX triggers',
    () async {
      var count = 0;
      var now = DateTime.utc(2026, 11, 17, 12);
      final service = AudioService(
        backend: (_, _) async => count++,
        clock: () => now,
        minRepeatIntervalMs: 110,
      );
      addTearDown(service.dispose);

      await service.playCrash(intoWater: false);
      now = now.add(const Duration(milliseconds: 50));
      await service.playCrash(intoWater: false);
      expect(count, 1);

      now = now.add(const Duration(milliseconds: 70));
      await service.playCrash(intoWater: false);
      expect(count, 2);
    },
  );

  test(
    'logs and absorbs backend errors safely in headless environments',
    () async {
      GameLog.clear();
      addTearDown(GameLog.clear);
      final service = AudioService(
        backend: (_, _) => Future<void>.error(StateError('no audio channel')),
      );
      addTearDown(service.dispose);

      await expectLater(service.playGoalReached(), completes);
      expect(
        GameLog.entries.any(
          (e) =>
              e.category == 'audio' &&
              e.message.contains('sfx/sfx_goal_01.wav') &&
              e.message.contains('no audio channel'),
        ),
        isTrue,
      );
    },
  );

  test('all 5 synthesized WAV assets exist with valid RIFF/WAVE headers', () {
    const files = [
      'assets/audio/sfx/sfx_switch_01.wav',
      'assets/audio/sfx/sfx_miss_01.wav',
      'assets/audio/sfx/sfx_crash_01.wav',
      'assets/audio/sfx/sfx_splash_01.wav',
      'assets/audio/sfx/sfx_goal_01.wav',
    ];
    for (final path in files) {
      final bytes = File(path).readAsBytesSync();
      expect(bytes.length, greaterThan(2000), reason: path);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF', reason: path);
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE', reason: path);
    }
  });
}
