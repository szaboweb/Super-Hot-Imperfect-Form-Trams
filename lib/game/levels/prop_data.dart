/// Kinds of level decoration/gameplay props placed by `props` in the level JSON.
enum PropType {
  /// Flat-roofed house beside the track (drawn in the canopy layer).
  building,

  /// Ground-mounted signal light/arrow next to the rails.
  signal,

  /// Gap in the ground (river, canal); the depth layer shows through it.
  channel,
}

/// One placed prop. Centre position in world px; [rotationDeg] is clockwise.
class PropData {
  const PropData({
    required this.type,
    required this.x,
    required this.y,
    this.width = 0,
    this.height = 0,
    this.rotationDeg = 0,
    this.state,
  });

  factory PropData.fromJson(Map<String, dynamic> json) {
    final name = json['type'] as String;
    final type = PropType.values.asNameMap()[name];
    if (type == null) throw FormatException('Unknown prop type "$name"');
    return PropData(
      type: type,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num?)?.toDouble() ?? 0,
      height: (json['height'] as num?)?.toDouble() ?? 0,
      rotationDeg: (json['rotation'] as num?)?.toDouble() ?? 0,
      state: json['state'] as String?,
    );
  }

  static const Set<String> signalStates = {'green', 'red'};

  final PropType type;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotationDeg;

  /// Signal colour for [PropType.signal] (`green` / `red`).
  final String? state;

  List<String> validate() {
    final errors = <String>[];
    if (type != PropType.signal && (width <= 0 || height <= 0)) {
      errors.add('${type.name} at ($x, $y) needs width and height > 0');
    }
    if (type == PropType.signal &&
        state != null &&
        !signalStates.contains(state)) {
      errors.add('signal at ($x, $y) has unknown state "$state"');
    }
    return errors;
  }
}
