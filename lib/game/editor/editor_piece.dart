/// A cell edge of the editor grid (screen directions: north = up = -y).
enum EditorSide {
  north(0, -1),
  east(1, 0),
  south(0, 1),
  west(-1, 0);

  const EditorSide(this.dCol, this.dRow);

  final int dCol;
  final int dRow;

  /// Opposite cell edge (`north <-> south`, `east <-> west`).
  EditorSide get opposite => switch (this) {
    north => south,
    south => north,
    east => west,
    west => east,
  };

  /// True for east and west edges.
  bool get isHorizontal => this == east || this == west;
}

/// Everything the user can drag out of the four sidebar shelves.
enum EditorPiece {
  straightH(sides: [EditorSide.west, EditorSide.east]),
  straightV(sides: [EditorSide.north, EditorSide.south]),
  cornerNE(sides: [EditorSide.north, EditorSide.east]),
  cornerNW(sides: [EditorSide.north, EditorSide.west]),
  cornerSE(sides: [EditorSide.south, EditorSide.east]),
  cornerSW(sides: [EditorSide.south, EditorSide.west]),

  /// Passive 90-degree flat rail crossing (no switch mechanism).
  crossing(),

  /// Dead-end buffer stop terminating an open rail spur.
  bufferStop(),

  /// Round turntable on a crossing cell: rotates 90 degrees onto the other loop.
  switchCircle(),

  /// Sliding table on a straight cell: slides onto the parallel lane next to it.
  switchRectangle(),

  /// Y-turn on a crossing cell: reverses the tram 180 degrees on its own loop.
  switchTriangle(),

  /// Tight-radius 3-way T-switches (perpendicular stem faces north/south/east/west).
  switchTNorth(),
  switchTSouth(),
  switchTEast(),
  switchTWest(),

  /// S-curve parallel-lane Y-switches (straight default, SHIFT shifts 1 lane left/right).
  switchYNorthLeft(sides: [EditorSide.north, EditorSide.south]),
  switchYNorthRight(sides: [EditorSide.north, EditorSide.south]),
  switchYSouthLeft(sides: [EditorSide.north, EditorSide.south]),
  switchYSouthRight(sides: [EditorSide.north, EditorSide.south]),
  switchYEastLeft(sides: [EditorSide.west, EditorSide.east]),
  switchYEastRight(sides: [EditorSide.west, EditorSide.east]),
  switchYWestLeft(sides: [EditorSide.west, EditorSide.east]),
  switchYWestRight(sides: [EditorSide.west, EditorSide.east]),

  /// Track barrier that closes behind passing trams and opens on SHIFT.
  gate(),

  /// Special icy rail section that boosts tram acceleration and top speed.
  railIce(),

  /// Special melted rail section that slows trams down with viscous drag.
  railMelted(),

  /// Player 1 tram (WASD + left SHIFT), sits on a plain rail cell.
  tramGreen(),

  /// Player 2 tram (arrows + right SHIFT), sits on a plain rail cell.
  tramRed();

  const EditorPiece({this.sides = const []});

  /// Fixed edges the rail connects (empty for switches, zones, crossings and trams).
  final List<EditorSide> sides;

  /// Stem edge of a directional 3-way T-switch, or null for other pieces.
  EditorSide? get tStemSide => switch (this) {
    switchTNorth => EditorSide.north,
    switchTSouth => EditorSide.south,
    switchTEast => EditorSide.east,
    switchTWest => EditorSide.west,
    _ => null,
  };

  /// True for the 4 directional T-switches.
  bool get isTSwitch => tStemSide != null;

  /// Diverging (SHIFT) travel direction of an S-curve Y-switch, or null.
  EditorSide? get yForwardSide => switch (this) {
    switchYNorthLeft || switchYNorthRight => EditorSide.north,
    switchYSouthLeft || switchYSouthRight => EditorSide.south,
    switchYEastLeft || switchYEastRight => EditorSide.east,
    switchYWestLeft || switchYWestRight => EditorSide.west,
    _ => null,
  };

  /// Parallel lane edge toward which an S-curve Y-switch branches on SHIFT.
  EditorSide? get yBranchSide => switch (this) {
    switchYNorthLeft || switchYSouthRight => EditorSide.west,
    switchYNorthRight || switchYSouthLeft => EditorSide.east,
    switchYEastLeft || switchYWestRight => EditorSide.north,
    switchYEastRight || switchYWestLeft => EditorSide.south,
    _ => null,
  };

  /// True for the 8 directional S-curve parallel-lane Y-switches.
  bool get isYSwitch => yForwardSide != null;

  /// Whether this piece accepts a rail connection on [side] (with [verticalInline] for auto-straight pieces).
  bool connectsToSide(EditorSide side, {bool verticalInline = false}) {
    if (isCrossing) return true;
    if (tStemSide case final stem?) return side != stem.opposite;
    if (isAutoStraight) {
      return verticalInline ? !side.isHorizontal : side.isHorizontal;
    }
    return sides.contains(side);
  }

  /// True for player tram spawn markers.
  bool get isTram => this == tramGreen || this == tramRed;

  /// True for controllable track switches.
  bool get isSwitch =>
      this == switchCircle ||
      this == switchRectangle ||
      this == switchTriangle ||
      isTSwitch ||
      isYSwitch;

  /// Pieces that occupy the rail layer of a cell (everything except trams).
  bool get isRail => !isTram;

  /// Straight pieces that automatically orient horizontal or vertical from neighbours.
  bool get isAutoStraight =>
      this == switchRectangle ||
      this == gate ||
      this == railIce ||
      this == railMelted;

  /// Rails a tram spawn marker may sit on.
  bool get isPlainRail =>
      (sides.isNotEmpty && !isYSwitch) ||
      this == switchRectangle ||
      this == railIce ||
      this == railMelted;

  /// Four-way crossings supporting both horizontal and vertical passes.
  bool get isCrossing =>
      this == crossing || this == switchCircle || this == switchTriangle;

  /// Rail pieces that cannot share a cell with a spawned tram marker.
  bool get blocksTram =>
      isCrossing ||
      isTSwitch ||
      isYSwitch ||
      this == bufferStop ||
      this == gate;
}
