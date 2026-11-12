import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/core/game_log.dart';

void main() {
  tearDown(() => GameLog.sink = null);

  test('lines carry a timestamp, a tag and the message', () {
    final lines = <String>[];
    GameLog.sink = lines.add;
    GameLog.event('switch', 'sw_green: W/S 12.0px before entry -> HIT');
    expect(lines.single, matches(r'^\[\s*\d+\.\d{2}s\] switch: sw_green: W/S'));
  });
}
