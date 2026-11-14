import 'dart:math' as math;

import '../systems/track_graph.dart';
import '../systems/track_path.dart';
import '../systems/turntable_movement.dart';

/// One L-turn between two segments, as written in the level JSON (`links`).
typedef CrossoverLinkData = ({String from, String to});

/// Footprint of a crossover platform (platformShape in the level JSON).
enum PlatformShape {
  /// Round turntable (default): rotates the tram onto the crossing loop.
  circle,

  /// Sliding table: slides sideways onto the parallel same-direction lane.
  rectangle,

  /// Square junction tile (rotates like [circle]).
  square,

  /// Y-turn platform: reverses the tram onto the reversed path of its own loop.
  triangle;

  /// Parses the JSON name; unknown or missing names fall back to [circle].
  static PlatformShape parse(Object? name) => PlatformShape.values.firstWhere(
    (s) => s.name == name,
    orElse: () => PlatformShape.circle,
  );
}

/// A crossover switch: a turntable where two loops cross, parsed from the
/// `crossovers` list of the level JSON. A tram turns the disc with its own SHIFT.
class CrossoverData {
  const CrossoverData({
    required this.id,
    required this.x,
    required this.y,
    required this.links,
    this.radius = 48,
    this.shape = PlatformShape.circle,
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
      shape: PlatformShape.parse(json['platformShape']),
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

  /// Visual footprint of the platform.
  final PlatformShape shape;

  /// Offset of the signal light from the crossing point (outside the disc).
  final double signalDx;
  final double signalDy;
  final List<CrossoverLinkData> links;

  math.Point<double> get center => math.Point(x, y);

  /// How the platform moves a tram, from its shape.
  TurntableMovement get movement => switch (shape) {
    PlatformShape.rectangle => TurntableMovement.slide,
    PlatformShape.triangle => TurntableMovement.reverse,
    PlatformShape.circle || PlatformShape.square => TurntableMovement.rotate,
  };

  List<String> validate(Map<String, TrackSegment> segments) {
    final errors = <String>[];
    if (links.isEmpty) errors.add('crossover "$id" has no links');
    if (radius <= 0) errors.add('crossover "$id" needs radius > 0');
    for (final link in links) {
      errors.addAll(_validateLink(link, segments));
    }
    return errors;
  }

  /// A rectangle slides between two parallel lanes, so its centre may sit between them
  /// (within [radius] of each); a triangle reverses one segment (`from == to`); the
  /// others rotate between two segments that cross exactly at the centre.
  List<String> _validateLink(
    CrossoverLinkData link,
    Map<String, TrackSegment> segments,
  ) {
    final errors = <String>[];
    final same = link.from == link.to;
    if (shape == PlatformShape.triangle && !same) {
      errors.add('crossover "$id" triangle link needs from == to (reverse)');
    } else if (shape != PlatformShape.triangle && same) {
      errors.add('crossover "$id" link needs two different segments');
    }
    final maxGap = movement == TurntableMovement.slide ? radius : 2;
    final paths = <TrackPath>[];
    for (final name in {link.from, link.to}) {
      final points = segments[name]?.points ?? const [];
      if (points.length < 2) {
        errors.add('crossover "$id" uses segment "$name" without geometry');
      } else if (TrackPath(points).nearest(center).gap > maxGap) {
        errors.add('crossover "$id" is not on segment "$name"');
      } else {
        paths.add(TrackPath(points));
      }
    }
    if (movement == TurntableMovement.slide && paths.length == 2) {
      final a = paths[0].headingAt(paths[0].nearest(center).along);
      final b = paths[1].headingAt(paths[1].nearest(center).along);
      if (math.atan2(math.sin(a - b), math.cos(a - b)).abs() > 0.2) {
        errors.add(
          'crossover "$id" slide needs parallel, same-direction lanes',
        );
      }
    }
    return errors;
  }
}
