import 'dart:math' show Point;

/// What happens to a tram that reaches the end of a track segment.
enum TrackEnd {
  /// Continues into the next node.
  connected,

  /// Buffer stop: tram crashes.
  deadEnd,

  /// Track ends at a broken bridge / quay: tram falls into the river.
  river,

  /// Track leads into a construction site: tram crashes.
  construction,
}

/// A directed track segment, ending in either another segment or a hazard.
class TrackSegment {
  const TrackSegment({
    required this.id,
    this.end = TrackEnd.connected,
    this.nextSegment,
    this.points = const [],
  });

  final String id;
  final TrackEnd end;

  /// Continuation segment id (if [end] is [TrackEnd.connected]).
  final String? nextSegment;

  /// Rail centre-line in world px (empty = no geometry yet).
  final List<Point<double>> points;
}

/// Graph of directed segments for one level.
class TrackGraph {
  TrackGraph({required Iterable<TrackSegment> segments})
    : segments = {for (final s in segments) s.id: s};

  final Map<String, TrackSegment> segments;

  /// Resolves where a tram leaving [segmentId] ends up right now.
  /// Returns the next segment id, or the hazard that ends the segment.
  ({String? next, TrackEnd end}) advance(String segmentId) {
    final seg = segments[segmentId]!;
    if (seg.end != TrackEnd.connected) return (next: null, end: seg.end);
    return (next: seg.nextSegment, end: TrackEnd.connected);
  }
}
