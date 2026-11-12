import 'dart:math' show Point;

import '../systems/track_graph.dart';
import '../systems/track_path.dart';

/// One L-turn between two segments, as written in the level JSON (`links`).
typedef CrossoverLinkData = ({String from, String to});

/// A crossover switch: a turntable where two loops cross, parsed from the
/// `crossovers` list of the level JSON. A tram turns the disc with its own SHIFT.
class CrossoverData {
  const CrossoverData({
    required this.id,
    required this.x,
    required this.y,
    required this.links,
    this.radius = 48,
    this.signalDx = -56,
    this.signalDy = -50,
  });

  factory CrossoverData.fromJson(Map<String, dynamic> json) {
    final offset = json['signalOffset'] as List?;
    return CrossoverData(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      radius: (json['radius'] as num?)?.toDouble() ?? 48,
      signalDx: (offset?[0] as num?)?.toDouble() ?? -56,
      signalDy: (offset?[1] as num?)?.toDouble() ?? -50,
      links: [
        for (final l in (json['links'] as List? ?? const []))
          (from: (l as Map)['from'] as String, to: l['to'] as String),
      ],
    );
  }

  final String id;

  /// Crossing point in world px (both linked segments pass through it).
  final double x;
  final double y;

  /// Radius of the turntable disc in px.
  final double radius;

  /// Offset of the signal light from the crossing point (outside the disc).
  final double signalDx;
  final double signalDy;
  final List<CrossoverLinkData> links;

  Point<double> get center => Point(x, y);

  List<String> validate(Map<String, TrackSegment> segments) {
    final errors = <String>[];
    if (links.isEmpty) errors.add('crossover "$id" has no links');
    if (radius <= 0) errors.add('crossover "$id" needs radius > 0');
    for (final link in links) {
      for (final name in [link.from, link.to]) {
        final points = segments[name]?.points ?? const [];
        if (points.length < 2) {
          errors.add('crossover "$id" uses segment "$name" without geometry');
        } else if (TrackPath(points).nearest(center).gap > 2) {
          errors.add('crossover "$id" is not on segment "$name"');
        }
      }
    }
    return errors;
  }
}
