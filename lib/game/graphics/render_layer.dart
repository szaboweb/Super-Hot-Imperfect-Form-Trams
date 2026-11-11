/// Draw order of the world, bottom to top (Flame `priority`).
/// Every world component takes its priority from here; add finer ordering as `+ n`.
///
/// Above everything sits the HUD, which lives in the camera viewport (screen
/// coordinates) instead of the world.
enum RenderLayer {
  /// Riverbed, canal, pit under collapsed bridges: wrecks fall into it.
  depth,

  /// Asphalt, pavement, cobbles, bridge decks, skid marks.
  ground,

  /// Rails, switch blades, signal lights and arrows.
  track,

  /// Trams, wrecks, traffic, pedestrians.
  entities,

  /// Rooftops, overhead wires, poles, pantograph sparks.
  canopy,

  /// Smoke, headlight cones, rain, fog and cloud shadows.
  atmosphere;

  int get priority => index * 100;
}
