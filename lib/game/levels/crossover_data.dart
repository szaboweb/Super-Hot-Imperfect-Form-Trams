import 'dart:math' as math;

import '../systems/track_graph.dart';
import '../systems/track_path.dart';
import '../systems/turntable_movement.dart';
import '../systems/turntable_turn_builder.dart';

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
  triangle,

  /// Tight-radius Y-switch: curves left or right with SHIFT + directional key.
  wye,

  /// S-curve parallel-lane Y-switch: branches on SHIFT and auto-merges back.
  turnout;

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
    this.stemX,
    this.stemY,
    this.forwardDx,
    this.forwardDy,
  });

  factory CrossoverData.fromJson(Map<String, dynamic> json) {
    final offset = json['signalOffset'] as List?;
    final stem = json['stemPoint'] as List?;
    final fwd = json['forward'] as List?;
    return CrossoverData(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      radius: (json['radius'] as num?)?.toDouble() ?? 48,
      shape: PlatformShape.parse(json['platformShape']),
      signalDx: (offset?[0] as num?)?.toDouble() ?? -56,
      signalDy: (offset?[1] as num?)?.toDouble() ?? -50,
      stemX: stem != null && stem.isNotEmpty
          ? (stem[0] as num?)?.toDouble()
          : null,
      stemY: stem != null && stem.length > 1
          ? (stem[1] as num?)?.toDouble()
          : null,
      forwardDx: fwd != null && fwd.isNotEmpty
          ? (fwd[0] as num?)?.toDouble()
          : null,
      forwardDy: fwd != null && fwd.length > 1
          ? (fwd[1] as num?)?.toDouble()
          : null,
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

  /// Optional stem-lane anchor point in world px for [PlatformShape.turnout].
  final double? stemX;
  final double? stemY;

  /// Optional world forward direction unit vector for [PlatformShape.turnout].
  final double? forwardDx;
  final double? forwardDy;

  final List<CrossoverLinkData> links;

  math.Point<double> get center => math.Point(x, y);

  math.Point<double>? get stemPoint =>
      (stemX != null && stemY != null) ? math.Point(stemX!, stemY!) : null;

  math.Point<double>? get forward => (forwardDx != null && forwardDy != null)
      ? math.Point(forwardDx!, forwardDy!)
      : null;

  /// How the platform moves a tram, from its shape.
  TurntableMovement get movement => switch (shape) {
    PlatformShape.rectangle => TurntableMovement.slide,
    PlatformShape.triangle => TurntableMovement.reverse,
    PlatformShape.wye => TurntableMovement.curve,
    PlatformShape.turnout => TurntableMovement.turnout,
    PlatformShape.circle || PlatformShape.square => TurntableMovement.rotate,
  };

  List<String> validate(Map<String, TrackSegment> segments) {
    final errors = <String>[];
    if (links.isEmpty) {
      errors.add('a(z) "$id" váltóhoz nem tartozik kapcsolat (links)');
    }
    if (radius <= 0) {
      errors.add('a(z) "$id" váltó sugara (radius) > 0 kell legyen');
    }
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
      errors.add(
        'a(z) "$id" háromszög váltónál from == to szükséges (fordítás)',
      );
    }
    final maxGap =
        (movement == TurntableMovement.slide ||
            movement == TurntableMovement.turnout)
        ? radius
        : 2.0;
    final resolved = <String, TrackPath>{};
    for (final name in {link.from, link.to}) {
      final path = _validatedPath(name, segments, maxGap, errors);
      if (path != null) resolved[name] = path;
    }
    final fromPath = resolved[link.from];
    final toPath = resolved[link.to];
    if (fromPath != null && toPath != null) {
      _validateMovementGeometry(same, fromPath, toPath, errors);
    }
    return errors;
  }

  TrackPath? _validatedPath(
    String name,
    Map<String, TrackSegment> segments,
    double maxGap,
    List<String> errors,
  ) {
    final points = segments[name]?.points ?? const [];
    if (points.length < 2) {
      errors.add('a(z) "$id" váltó "$name" szakaszának nincs geometriája');
      return null;
    }
    final path = TrackPath(points);
    if (path.nearest(center).gap > maxGap) {
      errors.add('a(z) "$id" váltó nincs rajta a(z) "$name" szakaszon');
      return null;
    }
    return path;
  }

  void _validateMovementGeometry(
    bool same,
    TrackPath fromPath,
    TrackPath toPath,
    List<String> errors,
  ) {
    if (movement == TurntableMovement.slide) {
      if (!TurntableTurnBuilder.hasValidSlide(
        fromPath,
        toPath,
        center,
        radius,
      )) {
        errors.add(
          'a(z) "$id" csúsztatós váltóhoz két párhuzamos sáv szükséges',
        );
      }
    } else if (movement == TurntableMovement.turnout) {
      if (!TurntableTurnBuilder.hasValidTurnout(
        fromPath,
        toPath,
        center,
        radius,
        stemPoint: stemPoint,
        forward: forward,
      )) {
        errors.add('a(z) "$id" Y váltóhoz két párhuzamos sáv szükséges');
      }
    } else if (same &&
        (movement == TurntableMovement.rotate ||
            movement == TurntableMovement.curve) &&
        fromPath.crossingsNear(center).length < 2) {
      errors.add(
        'a(z) "$id" forgóváltóhoz két áthaladás szükséges a középponton',
      );
    }
  }
}
