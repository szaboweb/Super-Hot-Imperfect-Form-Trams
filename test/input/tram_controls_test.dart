import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/input/tram_controls.dart';

void main() {
  test('each layout reacts only to its own keys', () {
    final arrowsUp = {LogicalKeyboardKey.arrowUp};
    final wasdUp = {LogicalKeyboardKey.keyW};
    expect(TramControls.arrows.throttleFor(arrowsUp), 1);
    expect(TramControls.arrows.throttleFor(wasdUp), 0);
    expect(TramControls.wasd.throttleFor(wasdUp), 1);
    expect(TramControls.wasd.throttleFor(arrowsUp), 0);
  });

  test('brake gives -1 and both keys cancel out', () {
    expect(TramControls.arrows.throttleFor({LogicalKeyboardKey.arrowDown}), -1);
    expect(
      TramControls.wasd.throttleFor({
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.keyS,
      }),
      0,
    );
  });
}
