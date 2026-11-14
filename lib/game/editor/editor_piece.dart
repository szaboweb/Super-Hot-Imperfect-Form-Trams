/// A cell edge of the editor grid (screen directions: north = up = -y).
enum EditorSide {
  north(0, -1),
  east(1, 0),
  south(0, 1),
  west(-1, 0);

  const EditorSide(this.dCol, this.dRow);

  final int dCol;
  final int dRow;

  EditorSide get opposite => switch (this) {
    north => south,
    south => north,
    east => west,
    west => east,
  };

  bool get isHorizontal => this == east || this == west;
}

/// Everything the user can drag out of the sidebar shelves.
enum EditorPiece {
  straightH(sides: [EditorSide.west, EditorSide.east]),
  straightV(sides: [EditorSide.north, EditorSide.south]),
  cornerNE(sides: [EditorSide.north, EditorSide.east]),
  cornerNW(sides: [EditorSide.north, EditorSide.west]),
  cornerSE(sides: [EditorSide.south, EditorSide.east]),
  cornerSW(sides: [EditorSide.south, EditorSide.west]),

  /// Round turntable on a crossing cell: rotates 90 degrees onto the other loop.
  switchCircle(),

  /// Sliding table on a straight cell: slides onto the parallel lane next to it.
  switchRectangle(),

  /// Y-turn on a crossing cell: reverses the tram on its own loop.
  switchTriangle(),

  /// Player 1 tram (WASD + left SHIFT), sits on a plain rail cell.
  tramGreen(),

  /// Player 2 tram (arrows + right SHIFT), sits on a plain rail cell.
  tramRed();

  const EditorPiece({this.sides = const []});

  /// Fixed edges the rail connects (empty for switches and trams).
  final List<EditorSide> sides;

  bool get isTram => this == tramGreen || this == tramRed;

  bool get isSwitch =>
      this == switchCircle || this == switchRectangle || this == switchTriangle;

  /// Pieces that occupy the rail layer of a cell (everything but trams).
  bool get isRail => !isTram;

  /// Rails a tram marker may sit on (a rectangle behaves like a straight).
  bool get isPlainRail => sides.isNotEmpty || this == switchRectangle;

  /// A crossing cell: all four edges, two straight passes (horizontal and vertical).
  bool get isCrossing => this == switchCircle || this == switchTriangle;
}
