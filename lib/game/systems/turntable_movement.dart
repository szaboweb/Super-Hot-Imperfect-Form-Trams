/// How a crossover platform carries a tram from one track to the next.
enum TurntableMovement {
  /// The platform turns by the angle between the two tracks (circle, square).
  rotate,

  /// The platform slides sideways onto the parallel track, heading unchanged (rectangle).
  slide,

  /// The tram runs a Y-shaped loop on the platform and leaves backwards on the
  /// reversed path of its own track (triangle).
  reverse,
}
