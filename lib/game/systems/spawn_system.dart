import 'dart:math' as math;

import '../levels/level_data.dart';

/// Schedules level tram spawns by elapsed time so delayed trams enter in order.
class SpawnSystem {
  /// Creates a spawn scheduler from [spawns], sorted ascending by spawn time
  /// while preserving original input order when times are equal.
  SpawnSystem(Iterable<SpawnData> spawns) : _queue = _sortStable(spawns);

  static const double _timeEpsilon = 1e-9;

  final List<SpawnData> _queue;
  int _cursor = 0;
  double _elapsed = 0.0;

  /// Total elapsed level time in seconds.
  double get elapsedSeconds => _elapsed;

  /// Number of spawns not yet emitted.
  int get pendingCount => _queue.length - _cursor;

  /// Whether any scheduled spawns remain in the queue.
  bool get hasPending => _cursor < _queue.length;

  /// Advances the clock by [dt] seconds and returns spawns ready at or before
  /// the new elapsed time (with `dt == 0` emitting `t <= 0` spawns).
  List<SpawnData> advance(double dt) {
    final step = dt.isNaN ? 0.0 : math.max(0.0, dt);
    _elapsed += step;

    final ready = <SpawnData>[];
    while (_cursor < _queue.length &&
        _queue[_cursor].time <= _elapsed + _timeEpsilon) {
      ready.add(_queue[_cursor]);
      _cursor++;
    }
    return ready;
  }

  static List<SpawnData> _sortStable(Iterable<SpawnData> spawns) {
    final list = spawns.toList();
    final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
    indexed.sort((a, b) {
      final byTime = a.$2.time.compareTo(b.$2.time);
      return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
    });
    return [for (final entry in indexed) entry.$2];
  }
}
