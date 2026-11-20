import 'dart:math' as math;

import '../systems/track_graph.dart';
import '../systems/track_path.dart';
import 'level_json_reader.dart';

/// A track barrier (`gates` list in the level JSON) that closes automatically
/// after a tram passes and opens when an approaching tram presses SHIFT.
class GateData {
  /// Creates a gate definition centred at ([x], [y]) with trigger [radius].
  const GateData({
    required this.id,
    required this.x,
    required this.y,
    this.radius = 36,
  });

  /// Parses one entry of the level JSON `gates` list.
  factory GateData.fromJson(Map<String, dynamic> json) => GateData(
    id: readRequiredString(json, 'id'),
    x: readRequiredDouble(json, 'x'),
    y: readRequiredDouble(json, 'y'),
    radius: readOptionalDouble(json, 'radius', 36),
  );

  /// Unique gate identifier within the level.
  final String id;

  /// World X coordinate (px) of the barrier post centre on a track segment.
  final double x;

  /// World Y coordinate (px) of the barrier post centre on a track segment.
  final double y;

  /// Zone radius (px) around [center] used for barrier geometry.
  final double radius;

  /// Gate centre point in world coordinates (px).
  math.Point<double> get center => math.Point(x, y);

  /// Validates that [id] is non-empty, [radius] is positive, and [center] lies
  /// within 2 px of at least one track segment in [segments].
  List<String> validate(Map<String, TrackSegment> segments) {
    final errors = <String>[];
    if (id.isEmpty) {
      errors.add('a sorompó (gate) id értéke nem lehet üres');
    }
    if (radius <= 0) {
      errors.add('a(z) "$id" sorompó sugara (radius) > 0 kell legyen');
    }
    var onTrack = false;
    for (final s in segments.values) {
      if (s.points.length < 2) continue;
      if (TrackPath(s.points).nearest(center).gap <= 2.0) {
        onTrack = true;
        break;
      }
    }
    if (!onTrack) {
      errors.add('a(z) "$id" sorompó nem esik egyetlen pályaszakaszra sem');
    }
    return errors;
  }
}
