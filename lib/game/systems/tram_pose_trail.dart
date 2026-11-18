import 'dart:math' as math;

/// Sampled 2D world position and heading along a vehicle's path history.
typedef PoseSample = ({math.Point<double> position, double heading});

typedef _TrailEntry = ({
  double along,
  math.Point<double> position,
  double heading,
});

/// Pure-Dart arc-length breadcrumb trail for articulated trailer cars.
///
/// Headings follow the game convention: `0` points up (`-y`), clockwise positive.
class TramPoseTrail {
  /// Creates a pose history retaining up to [maxHistoryPx] sampled every [minStepPx].
  TramPoseTrail({this.maxHistoryPx = 160, this.minStepPx = 1.5})
    : assert(maxHistoryPx > 0, 'maxHistoryPx must be positive'),
      assert(minStepPx > 0, 'minStepPx must be positive');

  /// Maximum path history length retained in world px.
  final double maxHistoryPx;

  /// Minimum movement step in world px before recording a new sample.
  final double minStepPx;

  final List<_TrailEntry> _entries = [];

  /// Resets the trail at [start] facing [heading], seeding a straight tail behind it.
  void reset(math.Point<double> start, double heading) {
    final tail = math.Point<double>(
      start.x - math.sin(heading) * maxHistoryPx,
      start.y + math.cos(heading) * maxHistoryPx,
    );
    _entries
      ..clear()
      ..add((along: 0, position: tail, heading: heading))
      ..add((along: maxHistoryPx, position: start, heading: heading));
  }

  /// Appends [position] and [heading] once the vehicle moves at least [minStepPx].
  void record(math.Point<double> position, double heading) {
    if (_entries.isEmpty) {
      reset(position, heading);
      return;
    }
    final last = _entries.last;
    final step = last.position.distanceTo(position);
    if (step < minStepPx) return;

    final nextAlong = last.along + step;
    _entries.add((along: nextAlong, position: position, heading: heading));
    while (_entries.length > 2 &&
        nextAlong - _entries[1].along > maxHistoryPx) {
      _entries.removeAt(0);
    }
  }

  /// Interpolates the historical pose [lagPx] behind the most recent sample.
  PoseSample sampleBehind(double lagPx) {
    if (_entries.isEmpty) {
      return (position: const math.Point(0, 0), heading: 0);
    }
    final clampedLag = lagPx.clamp(0.0, maxHistoryPx);
    final target = _entries.last.along - clampedLag;
    if (target <= _entries.first.along) {
      final oldest = _entries.first;
      return (position: oldest.position, heading: oldest.heading);
    }
    for (var i = _entries.length - 1; i >= 1; i--) {
      final a = _entries[i - 1];
      if (a.along > target) continue;
      final b = _entries[i];
      final span = b.along - a.along;
      final t = span <= 0 ? 0.0 : ((target - a.along) / span).clamp(0.0, 1.0);
      return _interpolate(a, b, t);
    }
    final latest = _entries.last;
    return (position: latest.position, heading: latest.heading);
  }

  static PoseSample _interpolate(_TrailEntry a, _TrailEntry b, double t) {
    final x = a.position.x + (b.position.x - a.position.x) * t;
    final y = a.position.y + (b.position.y - a.position.y) * t;
    final delta = math.atan2(
      math.sin(b.heading - a.heading),
      math.cos(b.heading - a.heading),
    );
    return (position: math.Point(x, y), heading: a.heading + delta * t);
  }
}
