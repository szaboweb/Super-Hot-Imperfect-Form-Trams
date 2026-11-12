import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/core/sticky_keys_flags.dart';
import 'package:super_hot_imperfect_form_trams/core/sticky_keys_guard.dart';

void main() {
  test('only the hotkey bit is switched off and on again', () {
    const flags = 0x1 | 0x4 | 0x8; // sticky on, hotkey active, confirm hotkey
    expect(isStickyHotkeyActive(flags), isTrue);
    final off = withStickyHotkeyDisabled(flags);
    expect(isStickyHotkeyActive(off), isFalse);
    expect(off, 0x1 | 0x8, reason: 'other bits are untouched');
    expect(withStickyHotkeyEnabled(off), flags);
  });

  test('disabling an already inactive hotkey changes nothing', () {
    expect(withStickyHotkeyDisabled(0x1), 0x1);
    expect(isStickyHotkeyActive(0x1), isFalse);
  });

  test('the guard can be suspended and restored repeatedly without errors', () {
    final guard = StickyKeysGuard();
    guard
      ..suspendHotkey()
      ..suspendHotkey()
      ..restore()
      ..restore();
  });
}
