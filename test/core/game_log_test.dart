import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/core/game_log.dart';

void main() {
  tearDown(() {
    GameLog.sink = null;
    GameLog.clear();
  });

  test('lines carry a timestamp, a tag and the message', () {
    final lines = <String>[];
    GameLog.sink = lines.add;
    GameLog.event('switch', 'sw_green: W/S 12.0px before entry -> HIT');
    expect(lines.single, matches(r'^\[\s*\d+\.\d{2}s\] switch: sw_green: W/S'));
  });

  test('stores structured entries, notifies listeners, and clears', () {
    var notifications = 0;
    void onNotify() => notifications++;
    GameLog.entriesNotifier.addListener(onNotify);
    addTearDown(() => GameLog.entriesNotifier.removeListener(onNotify));

    GameLog.event('editor', 'Első üzenet');
    GameLog.event('tram', 'Második üzenet');

    expect(notifications, 2);
    expect(GameLog.entries.length, 2);
    expect(GameLog.entries.first.category, 'editor');
    expect(GameLog.entries.first.message, 'Első üzenet');
    expect(GameLog.entries.last.category, 'tram');

    GameLog.clear();
    expect(GameLog.entries, isEmpty);
    expect(notifications, 3);
  });

  test('caps in-memory buffer at GameLog.maxEntries', () {
    for (var i = 0; i < GameLog.maxEntries + 15; i++) {
      GameLog.event('test', 'msg_$i');
    }
    expect(GameLog.entries.length, GameLog.maxEntries);
    expect(GameLog.entries.first.message, 'msg_15');
    expect(GameLog.entries.last.message, 'msg_${GameLog.maxEntries + 14}');
  });

  group('GameLogStore isolation and GameLog.resetForTest', () {
    test('separate GameLogStore instances keep entries, sinks, and notifiers isolated', () {
      final firstLines = <String>[];
      final secondLines = <String>[];
      final first = GameLogStore(maxEntries: 2, sink: firstLines.add);
      final second = GameLogStore(sink: secondLines.add, clock: Stopwatch());
      addTearDown(() {
        first.dispose();
        second.dispose();
      });

      var firstNotified = 0;
      var secondNotified = 0;
      first.entriesNotifier.addListener(() => firstNotified++);
      second.entriesNotifier.addListener(() => secondNotified++);

      first.event('a', 'one');
      first.event('a', 'two');
      first.event('a', 'three');
      second.event('b', 'only');

      expect(first.entries.map((e) => e.message), ['two', 'three']);
      expect(second.entries.map((e) => e.message), ['only']);
      expect(second.entries.single.timestamp, '   0.00s');
      expect(firstLines.length, 3);
      expect(secondLines.length, 1);
      expect(firstNotified, 3);
      expect(secondNotified, 1);
      expect(GameLog.entries, isEmpty);

      first.clear();
      expect(first.entries, isEmpty);
      expect(second.entries.length, 1);
      expect(firstNotified, 4);
      expect(secondNotified, 1);
    });

    test(
      'dispose is idempotent and prevents further listener notifications',
      () {
        final store = GameLogStore();
        var calls = 0;
        store.entriesNotifier.addListener(() => calls++);
        store.event('test', 'before dispose');
        expect(calls, 1);

        store.dispose();
        store.dispose();
        expect(
          () => store.entriesNotifier.addListener(() {}),
          throwsStateError,
        );
      },
    );

    test(
      'GameLog.resetForTest swaps GameLog.instance and resets sink and entries',
      () {
        final previous = GameLog.instance;
        final captured = <String>[];
        GameLog.sink = captured.add;
        GameLog.event('switch', 'before reset');

        expect(GameLog.entries.length, 1);
        expect(captured.length, 1);

        GameLog.resetForTest();

        expect(GameLog.instance, isNot(same(previous)));
        expect(GameLog.entries, isEmpty);
        expect(GameLog.sink, isNull);
        expect(GameLog.entriesNotifier, same(GameLog.instance.entriesNotifier));

        GameLog.event('switch', 'after reset');
        expect(GameLog.entries.single.message, 'after reset');
        expect(captured.length, 1);
      },
    );
  });
}
