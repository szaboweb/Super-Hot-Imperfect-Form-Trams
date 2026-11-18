import 'dart:math' as math;

import '../systems/track_graph.dart';
import '../systems/track_path.dart';

/// Surface speed-modifier kind for special rails (`zones` in the level JSON).
enum TrackZoneKind {
  /// Icy rail section that boosts tram acceleration and top speed.
  ice,

  /// Melted/tar rail section that slows trams down with heavy viscous drag.
  melted;

  /// Parses [raw] into a [TrackZoneKind] or throws [FormatException].
  static TrackZoneKind parse(Object? raw) =>
      TrackZoneKind.values.asNameMap()[raw] ??
      (throw FormatException('Ismeretlen zónatípus: "$raw"'));
}

/// A special rail zone (`zones` list in the level JSON) modifying tram speed.
class TrackZoneData {
  /// Creates a special track zone of [kind] centred at ([x], [y]).
  const TrackZoneData({
    required this.kind,
    required this.x,
    required this.y,
    this.radius = 32,
  });

  /// Parses one entry of the level JSON `zones` list.
  factory TrackZoneData.fromJson(Map<String, dynamic> json) => TrackZoneData(
    kind: TrackZoneKind.parse(json['kind']),
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    radius: (json['radius'] as num?)?.toDouble() ?? 32,
  );

  /// Surface modifier type ([TrackZoneKind.ice] or [TrackZoneKind.melted]).
  final TrackZoneKind kind;

  /// World X coordinate (px) of the zone centre.
  final double x;

  /// World Y coordinate (px) of the zone centre.
  final double y;

  /// Radius (px) within which the zone affects trams.
  final double radius;

  /// Zone centre point in world coordinates (px).
  math.Point<double> get center => math.Point(x, y);

  /// Validates that [radius] is positive and [center] lies within 4 px of at
  /// least one track segment in [segments].
  List<String> validate(Map<String, TrackSegment> segments) {
    final errors = <String>[];
    if (radius <= 0) {
      errors.add('a(z) "${kind.name}" zóna sugara (radius) > 0 kell legyen');
    }
    var onTrack = false;
    for (final s in segments.values) {
      if (s.points.length < 2) continue;
      if (TrackPath(s.points).nearest(center).gap <= 4.0) {
        onTrack = true;
        break;
      }
    }
    if (!onTrack) {
      errors.add(
        'a(z) "${kind.name}" zóna nem esik egyetlen pályaszakaszra sem',
      );
    }
    return errors;
  }
}
