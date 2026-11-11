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

/// A junction (switch). Trams arriving from [entry] leave via the currently
/// selected branch. The player can flip it with [toggle].
class SwitchNode {
  SwitchNode({
    required this.id,
    required this.straight,
    required this.diverging,
    this.diverge = false,
  });

  final String id;

  /// Segment ids the switch routes to.
  final String straight;
  final String diverging;

  /// True when set to the diverging branch.
  bool diverge;

  String get activeBranch => diverge ? diverging : straight;

  void toggle() => diverge = !diverge;
}

/// A directed track segment, ending in either another node or a hazard.
class TrackSegment {
  const TrackSegment({
    required this.id,
    this.end = TrackEnd.connected,
    this.nextSwitch,
    this.nextSegment,
  });

  final String id;
  final TrackEnd end;

  /// Switch located at the end of this segment (if [end] is connected).
  final String? nextSwitch;

  /// Plain continuation without a switch (if [end] is connected).
  final String? nextSegment;
}

/// Graph of segments and switches for one level.
class TrackGraph {
  TrackGraph({
    required Iterable<TrackSegment> segments,
    required Iterable<SwitchNode> switches,
  }) : segments = {for (final s in segments) s.id: s},
       switches = {for (final s in switches) s.id: s};

  final Map<String, TrackSegment> segments;
  final Map<String, SwitchNode> switches;

  /// Resolves where a tram leaving [segmentId] ends up right now.
  /// Returns the next segment id, or the hazard that ends the segment.
  ({String? next, TrackEnd end}) advance(String segmentId) {
    final seg = segments[segmentId]!;
    if (seg.end != TrackEnd.connected) return (next: null, end: seg.end);
    final sw = seg.nextSwitch;
    if (sw != null) {
      return (next: switches[sw]!.activeBranch, end: TrackEnd.connected);
    }
    return (next: seg.nextSegment, end: TrackEnd.connected);
  }
}
