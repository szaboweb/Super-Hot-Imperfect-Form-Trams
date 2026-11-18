import '../levels/gate_data.dart';
import 'crash_system.dart';
import 'track_graph.dart';
import 'track_path.dart';

/// Runtime state of a single level track barrier gate.
class GateInstance {
  /// Creates a runtime gate instance anchored on [basePath] at [along].
  GateInstance({
    required this.data,
    required this.baseSegmentId,
    required this.basePath,
    required this.along,
    required this.headingRad,
  });

  /// Immutable JSON configuration for this gate.
  final GateData data;

  /// Base segment identifier owning this gate.
  final String baseSegmentId;

  /// Forward polyline of [baseSegmentId].
  final TrackPath basePath;

  /// Distance (px) along [basePath] where the barrier post sits.
  final double along;

  /// Track heading (rad) at [along].
  final double headingRad;

  /// Whether the barrier is currently closed (starts open).
  bool isClosed = false;

  final Set<int> _tramsInside = {};
}

/// Pure-Dart system managing track barrier gates: auto-closing after a tram
/// passes, crashing trams into closed gates, and opening via SHIFT ahead.
class GateSystem {
  /// Creates a gate system by resolving [gates] onto [paths].
  GateSystem({
    required List<GateData> gates,
    required Map<String, TrackPath> paths,
  }) : _gates = _resolveGates(gates, paths);

  /// Half-width (px) of the open pass-through tracking zone around a gate.
  static const double passHalfZonePx = 30.0;

  /// Half-width (px) of the physical barrier collision zone when closed.
  static const double barrierHitHalfZonePx = 18.0;

  /// Maximum distance (px) ahead along travel direction where SHIFT opens a gate.
  static const double shiftOpenAheadMaxPx = 120.0;

  /// Tolerance (px) slightly past a gate where SHIFT can still open it.
  static const double shiftOpenBehindTolerancePx = 18.0;

  /// Radius (px) within which a stopped tram's SHIFT opens a nearby closed gate.
  static const double shiftOpenStoppedRadiusPx = 96.0;

  static const String _revSuffix = '_rev';

  final List<GateInstance> _gates;

  /// Unmodifiable list of resolved level gates.
  List<GateInstance> get gates => _gates;

  /// Advances gate states for [trams], returning any closed-barrier crashes and
  /// invoking [onAutoClosed] whenever an open gate shuts behind a passing tram.
  List<CrashEvent> step(
    List<TramPose> trams, {
    void Function(GateInstance gate)? onAutoClosed,
  }) {
    final crashes = <CrashEvent>[];
    final byIndex = {for (final t in trams) t.index: t};
    for (final gate in _gates) {
      if (gate.isClosed) {
        _collectClosedCrashes(gate, trams, crashes);
      } else {
        _updateOpenGate(gate, trams, byIndex, onAutoClosed);
      }
    }
    return crashes;
  }

  /// Opens and returns the closest closed gate on [path] within the SHIFT
  /// activation window for a tram at [distance] moving at [speed] px/s, or `null`.
  GateInstance? tryOpen({
    required TrackPath path,
    required double distance,
    required double speed,
  }) {
    GateInstance? best;
    var bestDist = double.infinity;
    for (final gate in _gates) {
      if (!gate.isClosed) continue;
      final ahead = _aheadOnPath(gate, path, distance, speed);
      if (ahead == null) continue;
      final inWindow = speed == 0
          ? ahead.abs() <= shiftOpenStoppedRadiusPx
          : ahead >= -shiftOpenBehindTolerancePx &&
                ahead <= shiftOpenAheadMaxPx;
      if (inWindow && ahead.abs() < bestDist) {
        bestDist = ahead.abs();
        best = gate;
      }
    }
    if (best != null) best.isClosed = false;
    return best;
  }

  /// Returns the smallest distance `ahead` (px) in `[0, shiftOpenAheadMaxPx]` to
  /// a closed gate on [path] when [speed] != 0, or `null` if none.
  double? closedGateDistanceAhead(
    TrackPath path,
    double distance,
    double speed,
  ) {
    if (speed == 0) return null;
    double? closest;
    for (final gate in _gates) {
      if (!gate.isClosed) continue;
      final ahead = _aheadOnPath(gate, path, distance, speed);
      if (ahead == null || ahead < 0 || ahead > shiftOpenAheadMaxPx) continue;
      if (closest == null || ahead < closest) closest = ahead;
    }
    return closest;
  }

  void _collectClosedCrashes(
    GateInstance gate,
    List<TramPose> trams,
    List<CrashEvent> crashes,
  ) {
    for (final t in trams) {
      if (t.isCrashed || t.isRidingTurntable) continue;
      final delta = _signedDelta(gate, t.segmentId, t.trackDistance);
      if (delta == null || delta.abs() > barrierHitHalfZonePx) continue;
      crashes.add(
        CrashEvent(
          tramIndices: [t.index],
          hazard: TrackEnd.deadEnd,
          position: gate.data.center,
          description: '${t.label} crashed into closed gate ${gate.data.id}',
        ),
      );
    }
  }

  void _updateOpenGate(
    GateInstance gate,
    List<TramPose> trams,
    Map<int, TramPose> byIndex,
    void Function(GateInstance gate)? onAutoClosed,
  ) {
    for (final idx in gate._tramsInside.toList()) {
      final t = byIndex[idx];
      if (t == null || t.isCrashed) {
        gate._tramsInside.remove(idx);
        continue;
      }
      if (t.isRidingTurntable) continue;
      final delta = _signedDelta(gate, t.segmentId, t.trackDistance);
      if (delta == null || delta.abs() > passHalfZonePx) {
        gate.isClosed = true;
        gate._tramsInside.clear();
        onAutoClosed?.call(gate);
        return;
      }
    }
    for (final t in trams) {
      if (t.isCrashed || t.isRidingTurntable) continue;
      final delta = _signedDelta(gate, t.segmentId, t.trackDistance);
      if (delta != null && delta.abs() <= passHalfZonePx) {
        gate._tramsInside.add(t.index);
      }
    }
  }

  static double? _signedDelta(
    GateInstance gate,
    String segmentId,
    double trackDistance,
  ) {
    final double rawAlong;
    if (segmentId == gate.baseSegmentId) {
      rawAlong = trackDistance;
    } else if (segmentId == '${gate.baseSegmentId}$_revSuffix') {
      rawAlong = gate.basePath.length - trackDistance;
    } else {
      return null;
    }
    return _wrapDelta(rawAlong - gate.along, gate.basePath);
  }

  static double? _aheadOnPath(
    GateInstance gate,
    TrackPath path,
    double distance,
    double speed,
  ) {
    final double gateAlong;
    if (identical(path, gate.basePath) || path.name == gate.baseSegmentId) {
      gateAlong = gate.along;
    } else if (identical(path, gate.basePath.reversed) ||
        path.name == '${gate.baseSegmentId}$_revSuffix') {
      gateAlong = gate.basePath.length - gate.along;
    } else {
      return null;
    }
    final raw = _wrapDelta(gateAlong - distance, path);
    return speed == 0 ? raw : raw * (speed > 0 ? 1.0 : -1.0);
  }

  static double _wrapDelta(double offset, TrackPath path) {
    if (!path.isClosed) return offset;
    final half = path.length / 2;
    return ((offset + half) % path.length) - half;
  }

  static List<GateInstance> _resolveGates(
    List<GateData> gates,
    Map<String, TrackPath> paths,
  ) {
    final resolved = <GateInstance>[];
    for (final gate in gates) {
      String? bestId;
      TrackPath? bestPath;
      var bestAlong = 0.0;
      var bestGap = 2.0001;
      for (final entry in paths.entries) {
        final hit = entry.value.nearest(gate.center);
        if (hit.gap < bestGap) {
          bestGap = hit.gap;
          bestId = entry.key;
          bestPath = entry.value;
          bestAlong = hit.along;
        }
      }
      if (bestId != null && bestPath != null) {
        resolved.add(
          GateInstance(
            data: gate,
            baseSegmentId: bestId,
            basePath: bestPath,
            along: bestAlong,
            headingRad: bestPath.headingAt(bestAlong),
          ),
        );
      }
    }
    return List.unmodifiable(resolved);
  }
}
