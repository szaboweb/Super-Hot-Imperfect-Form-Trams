import 'package:flutter/foundation.dart';

/// Debug-only console log for game events (SHIFT presses, turns). Not called per frame.
/// Lines look like `[  12.34s] switch: ...`; in release builds nothing is printed.
class GameLog {
  GameLog._();

  /// Set in tests to capture lines instead of printing them.
  static void Function(String line)? sink;

  static final Stopwatch _clock = Stopwatch()..start();

  static void event(String tag, String message) {
    final output = sink;
    if (output == null && !kDebugMode) return;
    final seconds = (_clock.elapsedMilliseconds / 1000).toStringAsFixed(2);
    final line = '[${seconds.padLeft(7)}s] $tag: $message';
    if (output != null) {
      output(line);
    } else {
      debugPrint(line);
    }
  }
}
