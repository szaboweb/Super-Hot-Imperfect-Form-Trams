import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';

import 'game_log.dart';
import 'sticky_keys_flags.dart';

const int _spiGetStickyKeys = 0x003A;
const int _spiSetStickyKeys = 0x003B;

final class _StickyKeys extends Struct {
  @Uint32()
  external int cbSize;

  @Uint32()
  external int dwFlags;
}

typedef _SpiNative = Int32 Function(Uint32, Uint32, Pointer<Void>, Uint32);
typedef _Spi = int Function(int, int, Pointer<Void>, int);

/// Windows only: keeps the Sticky Keys prompt (five times SHIFT) from popping up while the
/// game is in the foreground. The setting is changed for this session only (not written to
/// the user profile), and [restore] puts the shortcut back; on other platforms it does nothing.
class StickyKeysGuard {
  bool _suspended = false;

  late final _Spi? _spi = Platform.isWindows
      ? DynamicLibrary.open('user32.dll')
            .lookupFunction<_SpiNative, _Spi>('SystemParametersInfoW')
      : null;

  /// Switches the five-times-SHIFT shortcut off (if it was on).
  void suspendHotkey() {
    if (_suspended) return;
    final flags = _read();
    if (flags == null || !isStickyHotkeyActive(flags)) return;
    if (_write(withStickyHotkeyDisabled(flags))) {
      _suspended = true;
      GameLog.event('input', 'sticky keys shortcut off while the game runs');
    }
  }

  /// Switches the shortcut back on if [suspendHotkey] had turned it off.
  void restore() {
    if (!_suspended) return;
    final flags = _read();
    if (flags != null && _write(withStickyHotkeyEnabled(flags))) {
      _suspended = false;
      GameLog.event('input', 'sticky keys shortcut restored');
    }
  }

  int? _read() => _withStruct((ptr, size) {
    final ok = _spi!(_spiGetStickyKeys, size, ptr.cast(), 0) != 0;
    return ok ? ptr.ref.dwFlags : null;
  });

  bool _write(int flags) =>
      _withStruct((ptr, size) {
        ptr.ref.dwFlags = flags;
        // fWinIni 0: change the running session only, do not persist to the profile.
        return _spi!(_spiSetStickyKeys, size, ptr.cast(), 0) != 0;
      }) ??
      false;

  T? _withStruct<T>(T? Function(Pointer<_StickyKeys>, int) body) {
    if (_spi == null) return null;
    final ptr = calloc<_StickyKeys>();
    try {
      ptr.ref.cbSize = sizeOf<_StickyKeys>();
      return body(ptr, ptr.ref.cbSize);
    } finally {
      calloc.free(ptr);
    }
  }
}
