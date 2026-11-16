import 'dart:math' as math;

import 'track_graph.dart';
import 'track_path.dart';

/// Snapshot of a tram's state passed to [CrashSystem.step] for collision and hazard checks.
typedef TramPose = ({
  int index,
  String label,
  String segmentId,
  double trackDistance,
  double speed,
  math.Point<double> position,
  double heading,
  bool isRidingTurntable,
  bool isCrashed,
});

/// Result of one [CrashSystem.step] pass: detected crashes and open-end segment transitions.
typedef CrashStepResult = ({
  List<CrashEvent> crashes,
  List<({int tramIndex, TrackPath nextPath, double nextDistance})> transitions,
});

/// Immutable record of a tram collision or open-track hazard crash.
class CrashEvent {
  /// Creates a crash event involving [tramIndices] at world [position].
  const CrashEvent({
    required this.tramIndices,
    required this.position,
    required this.description,
    this.hazard,
  });

  /// Indices of the tram(s) involved in the crash.
  final List<int> tramIndices;

  /// Hazard that ended the tram's run, or `null` for a tram-vs-tram collision.
  final TrackEnd? hazard;

  /// World position (px) where the crash occurred.
  final math.Point<double> position;

  /// Human-readable crash summary for event logs.
  final String description;
}

/// Pure-Dart system detecting open-track end hazards, segment transitions, and tram collisions.
class CrashSystem {
  /// Creates a crash and transition checker for [graph] and [paths].
  CrashSystem({
    required this.graph,
    required this.paths,
    this.tramLength = 56,
    this.tramWidth = 20,
  });

  static const String _revSuffix = '_rev';
  static const double _eps = 1e-9;

  /// Track topology used to resolve segment exits and hazards.
  final TrackGraph graph;

  /// Polylines keyed by base segment id (reverse tracks use `.reversed`).
  final Map<String, TrackPath> paths;

  /// Total tram capsule length in world px.
  final double tramLength;

  /// Total tram capsule width in world px (and collision distance threshold).
  final double tramWidth;

  /// Evaluates open-segment ends and pairwise tram-vs-tram capsule collisions.
  CrashStepResult step(List<TramPose> trams) {
    final crashes = <CrashEvent>[];
    final transitions =
        <({int tramIndex, TrackPath nextPath, double nextDistance})>[];
    final crashedNow = List<bool>.filled(trams.length, false);

    for (var i = 0; i < trams.length; i++) {
      if (_checkOpenSegmentEnd(trams[i], crashes, transitions)) {
        crashedNow[i] = true;
      }
    }

    for (var i = 0; i < trams.length; i++) {
      final a = trams[i];
      if (a.isCrashed || crashedNow[i]) continue;
      _collideAgainstFollowing(trams, i, crashedNow, crashes);
    }

    return (crashes: crashes, transitions: transitions);
  }

  bool _checkOpenSegmentEnd(
    TramPose tram,
    List<CrashEvent> crashes,
    List<({int tramIndex, TrackPath nextPath, double nextDistance})>
    transitions,
  ) {
    if (tram.isCrashed || tram.isRidingTurntable) return false;

    final isRev = tram.segmentId.endsWith(_revSuffix);
    final baseId = isRev
        ? tram.segmentId.substring(0, tram.segmentId.length - _revSuffix.length)
        : tram.segmentId;
    final basePath = paths[baseId];
    if (basePath == null || basePath.isClosed) return false;
    if (!graph.segments.containsKey(baseId)) return false;

    final reachedForwardEnd = isRev
        ? tram.trackDistance < 0
        : tram.trackDistance >= basePath.length;
    if (reachedForwardEnd) {
      return _handleForwardEnd(
        tram,
        baseId,
        basePath,
        isRev,
        crashes,
        transitions,
      );
    }

    final reachedStartEnd = isRev
        ? tram.trackDistance >= basePath.length
        : tram.trackDistance < 0;
    if (!reachedStartEnd) return false;

    crashes.add(
      CrashEvent(
        tramIndices: [tram.index],
        hazard: TrackEnd.deadEnd,
        position: tram.position,
        description:
            '${tram.label} crashed into ${TrackEnd.deadEnd.name} on $baseId',
      ),
    );
    return true;
  }

  bool _handleForwardEnd(
    TramPose tram,
    String baseId,
    TrackPath basePath,
    bool isRev,
    List<CrashEvent> crashes,
    List<({int tramIndex, TrackPath nextPath, double nextDistance})>
    transitions,
  ) {
    final result = graph.advance(baseId);
    if (result.end != TrackEnd.connected) {
      crashes.add(
        CrashEvent(
          tramIndices: [tram.index],
          hazard: result.end,
          position: tram.position,
          description:
              '${tram.label} crashed into ${result.end.name} on $baseId',
        ),
      );
      return true;
    }

    final nextId = result.next;
    final nextBasePath = nextId == null ? null : paths[nextId];
    if (nextBasePath == null) return false;

    final nextPath = isRev ? nextBasePath.reversed : nextBasePath;
    final nextDistance = isRev
        ? nextPath.length + tram.trackDistance
        : tram.trackDistance - basePath.length;
    transitions.add((
      tramIndex: tram.index,
      nextPath: nextPath,
      nextDistance: nextDistance,
    ));
    return false;
  }

  void _collideAgainstFollowing(
    List<TramPose> trams,
    int i,
    List<bool> crashedNow,
    List<CrashEvent> crashes,
  ) {
    final a = trams[i];
    for (var j = i + 1; j < trams.length; j++) {
      final b = trams[j];
      if (b.isCrashed || crashedNow[j]) continue;
      if (_capsuleDistance(a, b) >= tramWidth) continue;

      crashedNow[i] = true;
      crashedNow[j] = true;
      crashes.add(
        CrashEvent(
          tramIndices: [a.index, b.index],
          position: math.Point(
            (a.position.x + b.position.x) * 0.5,
            (a.position.y + b.position.y) * 0.5,
          ),
          description: '${a.label} collided with ${b.label}',
        ),
      );
      return;
    }
  }

  double _capsuleDistance(TramPose a, TramPose b) {
    final halfSpine = math.max(0.0, (tramLength - tramWidth) / 2);
    final aSeg = _spineSegment(a, halfSpine);
    final bSeg = _spineSegment(b, halfSpine);
    return math.sqrt(_segmentDistanceSq(aSeg.a, aSeg.b, bSeg.a, bSeg.b));
  }

  ({math.Point<double> a, math.Point<double> b}) _spineSegment(
    TramPose tram,
    double halfSpine,
  ) {
    final fx = math.sin(tram.heading);
    final fy = -math.cos(tram.heading);
    return (
      a: math.Point(
        tram.position.x - fx * halfSpine,
        tram.position.y - fy * halfSpine,
      ),
      b: math.Point(
        tram.position.x + fx * halfSpine,
        tram.position.y + fy * halfSpine,
      ),
    );
  }

  // Christer Ericson's ClosestPtSegmentSegment (Real-Time Collision Detection §5.1.9).
  static double _segmentDistanceSq(
    math.Point<double> p1,
    math.Point<double> q1,
    math.Point<double> p2,
    math.Point<double> q2,
  ) {
    final d1x = q1.x - p1.x;
    final d1y = q1.y - p1.y;
    final d2x = q2.x - p2.x;
    final d2y = q2.y - p2.y;
    final rx = p1.x - p2.x;
    final ry = p1.y - p2.y;
    final a = d1x * d1x + d1y * d1y;
    final e = d2x * d2x + d2y * d2y;
    final f = d2x * rx + d2y * ry;
    final c = d1x * rx + d1y * ry;

    final (s, t) = _closestParams(a, e, c, f, d1x * d2x + d1y * d2y);
    final dx = (p1.x + d1x * s) - (p2.x + d2x * t);
    final dy = (p1.y + d1y * s) - (p2.y + d2y * t);
    return dx * dx + dy * dy;
  }

  static (double, double) _closestParams(
    double a,
    double e,
    double c,
    double f,
    double b,
  ) {
    if (a <= _eps && e <= _eps) return (0.0, 0.0);
    if (a <= _eps) return (0.0, (f / e).clamp(0.0, 1.0));
    if (e <= _eps) return ((-c / a).clamp(0.0, 1.0), 0.0);

    final denom = a * e - b * b;
    final s = denom > 1e-12 * a * e
        ? ((b * f - c * e) / denom).clamp(0.0, 1.0)
        : 0.0;
    final t = (b * s + f) / e;
    if (t < 0.0) return ((-c / a).clamp(0.0, 1.0), 0.0);
    if (t > 1.0) return (((b - c) / a).clamp(0.0, 1.0), 1.0);
    return (s, t);
  }
}
