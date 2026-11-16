import 'package:flutter/foundation.dart';

/// A single structured entry recorded by [GameLog].
class GameLogEntry {
  const GameLogEntry({
    required this.timestamp,
    required this.category,
    required this.message,
  });

  final String timestamp;
  final String category;
  final String message;

  /// Formats the entry in the classic `[  12.34s] tag: message` style.
  String get formatted => '[$timestamp] $category: $message';
}

/// In-memory ring-buffered and console log for game and editor events.
/// Lines look like `[  12.34s] switch: ...`; console printing is debug-only.
class GameLog {
  GameLog._();

  /// Maximum number of entries retained in memory.
  static const int maxEntries = 200;

  /// Set in tests to capture lines instead of printing them.
  static void Function(String line)? sink;

  /// Reactive list of recent log entries (oldest first, capped at [maxEntries]).
  static final ValueNotifier<List<GameLogEntry>> entriesNotifier =
      ValueNotifier<List<GameLogEntry>>(const []);

  static List<GameLogEntry> get entries => entriesNotifier.value;

  static final Stopwatch _clock = Stopwatch()..start();

  /// Records a new log entry, notifies listeners, and prints in debug mode.
  static void event(String tag, String message) {
    final seconds = (_clock.elapsedMilliseconds / 1000).toStringAsFixed(2);
    final entry = GameLogEntry(
      timestamp: '${seconds.padLeft(7)}s',
      category: tag,
      message: message,
    );
    _appendEntry(entry);

    final output = sink;
    if (output != null) {
      output(entry.formatted);
    } else if (kDebugMode) {
      debugPrint(entry.formatted);
    }
  }

  /// Clears all stored in-memory log entries and notifies listeners.
  static void clear() {
    if (entriesNotifier.value.isEmpty) return;
    entriesNotifier.value = const [];
  }

  static void _appendEntry(GameLogEntry entry) {
    final current = entriesNotifier.value;
    final start = current.length >= maxEntries
        ? current.length - maxEntries + 1
        : 0;
    final next = <GameLogEntry>[
      for (var i = start; i < current.length; i++) current[i],
      entry,
    ];
    entriesNotifier.value = List.unmodifiable(next);
  }
}
