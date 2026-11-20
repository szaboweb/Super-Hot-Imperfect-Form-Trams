import 'level_json_reader.dart';

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
    final name = readRequiredString(json, 'type');
    final type = PropType.values.asNameMap()[name];
    if (type == null) {
      throw FormatException('Ismeretlen tereptárgy-típus: "$name"');
    }
    return PropData(
      type: type,
      x: readRequiredDouble(json, 'x'),
      y: readRequiredDouble(json, 'y'),
      width: readOptionalDouble(json, 'width', 0),
      height: readOptionalDouble(json, 'height', 0),
      rotationDeg: readOptionalDouble(json, 'rotation', 0),
      state: readOptionalString(json, 'state'),
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
      errors.add('a(z) ${type.name} ($x, $y) elemhez width és height > 0 kell');
    }
    if (type == PropType.signal &&
        state != null &&
        !signalStates.contains(state)) {
      errors.add('a jelző ($x, $y) állapota ismeretlen: "$state"');
    }
    return errors;
  }
}
