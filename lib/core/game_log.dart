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

/// Instantiable in-memory ring-buffered and console log store.
class GameLogStore {
  /// Creates a log store with an optional [maxEntries] cap, [sink], and [clock].
  GameLogStore({
    this.maxEntries = GameLog.maxEntries,
    this.sink,
    Stopwatch? clock,
  }) : assert(maxEntries > 0, 'maxEntries must be positive'),
       _clock = clock ?? (Stopwatch()..start());

  /// Maximum number of entries retained in memory.
  final int maxEntries;

  /// Set in tests to capture lines instead of printing them.
  void Function(String line)? sink;

  /// Reactive list of recent log entries (oldest first, capped at [maxEntries]).
  final ValueNotifier<List<GameLogEntry>> entriesNotifier =
      ValueNotifier<List<GameLogEntry>>(const []);

  /// Snapshot of currently retained entries, oldest first.
  List<GameLogEntry> get entries => entriesNotifier.value;

  final Stopwatch _clock;
  bool _disposed = false;

  /// Records a new log entry, notifies listeners, and prints in debug mode.
  void event(String tag, String message) {
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
  void clear() {
    if (entriesNotifier.value.isEmpty) return;
    entriesNotifier.value = const [];
  }

  /// Releases the [entriesNotifier] and stops the internal stopwatch.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _clock.stop();
    entriesNotifier.dispose();
  }

  void _appendEntry(GameLogEntry entry) {
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

/// Global facade over a shared [GameLogStore] for game and editor events.
/// Lines look like `[  12.34s] switch: ...`; console printing is debug-only.
class GameLog {
  GameLog._();

  /// Maximum number of entries retained in memory by the default store.
  static const int maxEntries = 200;

  static GameLogStore _instance = GameLogStore();

  /// Shared [GameLogStore] backing the static [GameLog] methods.
  static GameLogStore get instance => _instance;

  /// Set in tests to capture lines instead of printing them.
  static void Function(String line)? get sink => _instance.sink;
  static set sink(void Function(String line)? value) => _instance.sink = value;

  /// Reactive list of recent log entries (oldest first, capped at [maxEntries]).
  static ValueNotifier<List<GameLogEntry>> get entriesNotifier =>
      _instance.entriesNotifier;

  /// Snapshot of currently retained entries, oldest first.
  static List<GameLogEntry> get entries => _instance.entries;

  /// Records a new log entry, notifies listeners, and prints in debug mode.
  static void event(String tag, String message) =>
      _instance.event(tag, message);

  /// Clears all stored in-memory log entries and notifies listeners.
  static void clear() => _instance.clear();

  /// Replaces [instance] with a fresh [GameLogStore] for isolated tests.
  @visibleForTesting
  static void resetForTest() {
    final previous = _instance;
    _instance = GameLogStore();
    previous.dispose();
  }
}
