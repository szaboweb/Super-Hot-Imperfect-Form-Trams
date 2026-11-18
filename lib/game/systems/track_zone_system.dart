import 'dart:math' as math;

import '../levels/track_zone_data.dart';
import 'track_path.dart';

/// Resolved special surface zone paired with the local track heading (rad).
typedef LoadedTrackZone = ({TrackZoneData data, double headingRad});

/// Physics modifiers applied to a tram while inside a [TrackZoneKind] zone.
typedef TrackZoneEffect = ({
  TrackZoneKind? kind,
  double boostAccel,
  double maxSpeedMultiplier,
  double dragPerSec,
  double brakeMultiplier,
});

/// Pure-Dart system resolving special rail surface zones (`ice`, `melted`)
/// and querying active speed/drag/brake modifiers at any world position.
class TrackZoneSystem {
  /// Creates a zone system by resolving [zones] onto the closest [paths].
  TrackZoneSystem({
    required List<TrackZoneData> zones,
    required Map<String, TrackPath> paths,
  }) : _zones = _resolveZones(zones, paths);

  /// Default physics modifiers when a tram is on normal rails.
  static const TrackZoneEffect neutralEffect = (
    kind: null,
    boostAccel: 0.0,
    maxSpeedMultiplier: 1.0,
    dragPerSec: 0.8,
    brakeMultiplier: 1.0,
  );

  static const TrackZoneEffect _iceEffect = (
    kind: TrackZoneKind.ice,
    boostAccel: 280.0,
    maxSpeedMultiplier: 1.45,
    dragPerSec: 0.98,
    brakeMultiplier: 0.45,
  );

  static const TrackZoneEffect _meltedEffect = (
    kind: TrackZoneKind.melted,
    boostAccel: -220.0,
    maxSpeedMultiplier: 0.45,
    dragPerSec: 0.22,
    brakeMultiplier: 1.25,
  );

  final List<LoadedTrackZone> _zones;

  /// Unmodifiable list of resolved track zones for rendering and queries.
  List<LoadedTrackZone> get zones => _zones;

  /// Returns the surface modifier active at world [position], or [neutralEffect].
  TrackZoneEffect effectAt(math.Point<double> position) {
    for (final zone in _zones) {
      if (position.distanceTo(zone.data.center) <= zone.data.radius) {
        return switch (zone.data.kind) {
          TrackZoneKind.ice => _iceEffect,
          TrackZoneKind.melted => _meltedEffect,
        };
      }
    }
    return neutralEffect;
  }

  static List<LoadedTrackZone> _resolveZones(
    List<TrackZoneData> zones,
    Map<String, TrackPath> paths,
  ) {
    final resolved = <LoadedTrackZone>[];
    for (final zone in zones) {
      TrackPath? bestPath;
      var bestAlong = 0.0;
      var bestGap = 4.0001;
      for (final path in paths.values) {
        final hit = path.nearest(zone.center);
        if (hit.gap < bestGap) {
          bestGap = hit.gap;
          bestPath = path;
          bestAlong = hit.along;
        }
      }
      final heading = bestPath?.headingAt(bestAlong) ?? 0.0;
      resolved.add((data: zone, headingRad: heading));
    }
    return List.unmodifiable(resolved);
  }
}
