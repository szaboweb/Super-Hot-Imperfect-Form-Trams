/// Bits of the Windows STICKYKEYS.dwFlags value (pure Dart, testable everywhere).
const int stickyHotkeyActive =
    0x4; // SKF_HOTKEYACTIVE: 5x SHIFT opens the dialog

/// True if pressing SHIFT five times would start the Sticky Keys prompt.
bool isStickyHotkeyActive(int flags) => flags & stickyHotkeyActive != 0;

/// [flags] with the five-times-SHIFT shortcut switched off (other bits untouched).
int withStickyHotkeyDisabled(int flags) => flags & ~stickyHotkeyActive;

/// [flags] with the five-times-SHIFT shortcut switched on again.
int withStickyHotkeyEnabled(int flags) => flags | stickyHotkeyActive;
