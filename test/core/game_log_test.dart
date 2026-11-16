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
}
