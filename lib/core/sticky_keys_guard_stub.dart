/// No-op guard for platforms without FFI (web). The real one is in
/// `sticky_keys_guard_ffi.dart`; see `sticky_keys_guard.dart` for the shared export.
class StickyKeysGuard {
  /// Does nothing here: a web page cannot change Windows settings.
  void suspendHotkey() {}

  /// Does nothing here.
  void restore() {}
}
