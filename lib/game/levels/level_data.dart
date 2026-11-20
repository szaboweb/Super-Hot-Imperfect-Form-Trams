import 'dart:math' show Point;

import '../../input/tram_controls.dart';
import '../systems/track_graph.dart';
import 'crossover_data.dart';
import 'gate_data.dart';
import 'level_json_reader.dart';
import 'prop_data.dart';
import 'track_zone_data.dart';

/// One scheduled tram spawn on a segment (see `spawns` in the level JSON).
class SpawnData {
  const SpawnData({
    required this.segment,
    required this.time,
    required this.speed,
    this.controls,
    this.startDistance = 0,
    this.color = 0xFFE4572E,
  });

  factory SpawnData.fromJson(Map<String, dynamic> json) {
    final controlsName = readOptionalString(json, 'controls');
    return SpawnData(
      segment: readRequiredString(json, 'segment'),
      time: readRequiredDouble(json, 'time'),
      speed: readRequiredDouble(json, 'speed'),
      controls: controlsName == null
          ? null
          : TramControls.values.asNameMap()[controlsName] ??
                (throw FormatException(
                  'Ismeretlen irányítás: "$controlsName"',
                )),
      startDistance: readOptionalDouble(json, 'startDistance', 0),
      color: readOptionalInt(json, 'color', 0xFFE4572E),
    );
  }

  final String segment;

  /// Seconds after level start.
  final double time;
  final double speed;

  /// Keyboard layout of the player driving this tram; null = AI/unmanned.
  final TramControls? controls;

  /// Where on the segment the tram starts, in px along its path.
  final double startDistance;

  /// Canvas body colour as ARGB int.
  final int color;
}

/// Parsed and validated level definition (see assets/data/levels/*.json).
class LevelData {
  LevelData._({
    required this.id,
    this.name,
    required this.city,
    required this.tileSize,
    required this.width,
    required this.height,
    required this.segments,
    required this.spawns,
    required this.props,
    required this.crossovers,
    required this.gates,
    required this.zones,
    required this.crashGoal,
  });

  /// Throws [FormatException] listing every problem found in [json].
  factory LevelData.fromJson(Map<String, dynamic> json) {
    final id = readOptionalString(json, 'id') ?? '<unknown>';
    final bounds = readOptionalMap(json, 'bounds');
    final goal = readOptionalMap(json, 'goal');
    final level = LevelData._(
      id: id,
      name: readOptionalString(json, 'name'),
      city: readOptionalString(json, 'city') ?? '',
      tileSize: readOptionalInt(json, 'tileSize', 64),
      width: bounds == null ? 1040 : readOptionalDouble(bounds, 'width', 1040),
      height: bounds == null ? 680 : readOptionalDouble(bounds, 'height', 680),
      segments: [
        for (final s in readOptionalList(json, 'segments'))
          _segmentFromJson(readMapItem(s, 'a "segments" elem')),
      ],
      spawns: [
        for (final s in readOptionalList(json, 'spawns'))
          SpawnData.fromJson(readMapItem(s, 'a "spawns" elem')),
      ],
      props: [
        for (final p in readOptionalList(json, 'props'))
          PropData.fromJson(readMapItem(p, 'a "props" elem')),
      ],
      crossovers: [
        for (final c in readOptionalList(json, 'crossovers'))
          CrossoverData.fromJson(readMapItem(c, 'a "crossovers" elem')),
      ],
      gates: [
        for (final g in readOptionalList(json, 'gates'))
          GateData.fromJson(readMapItem(g, 'a "gates" elem')),
      ],
      zones: [
        for (final z in readOptionalList(json, 'zones'))
          TrackZoneData.fromJson(readMapItem(z, 'a "zones" elem')),
      ],
      crashGoal: goal == null ? 0 : readOptionalInt(goal, 'crashes', 0),
    );
    final errors = level.validate();
    if (errors.isNotEmpty) {
      throw FormatException(
        'Érvénytelen pálya "$id":\n- ${errors.join('\n- ')}',
      );
    }
    return level;
  }

  final String id;

  /// Optional human-readable display name from JSON (`name`).
  final String? name;
  final String city;
  final int tileSize;

  /// Human-readable display title for menus, falling back to humanized [id].
  String get displayTitle {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    final words = id
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .toList();
    return words.isEmpty ? id : words.join(' ');
  }

  /// Playable area size in world px, centred on the origin.
  final double width;
  final double height;
  final List<TrackSegment> segments;
  final List<SpawnData> spawns;
  final List<PropData> props;

  /// L-shaped switches between loops (flipped with the owner's SHIFT key).
  final List<CrossoverData> crossovers;

  /// SHIFT-opened track barriers (`gates` in the level JSON).
  final List<GateData> gates;

  /// Ice and melted special rail zones (`zones` in the level JSON).
  final List<TrackZoneData> zones;
  final int crashGoal;

  /// Track graph of the level segments and end hazards.
  TrackGraph buildGraph() => TrackGraph(segments: segments);

  List<String> validate() {
    final errors = <String>[];
    final segmentIds = <String>{};
    for (final s in segments) {
      if (!segmentIds.add(s.id)) errors.add('ismétlődő szakasz: "${s.id}"');
      if (s.points.length == 1) {
        errors.add(
          'a(z) "${s.id}" szakasz geometriájához legalább 2 pont szükséges',
        );
      }
    }
    for (final s in segments) {
      if (s.end != TrackEnd.connected) continue;
      final next = s.nextSegment;
      if (next == null) {
        errors.add(
          'a(z) "${s.id}" összekötött szakasznál nextSegment szükséges',
        );
      } else if (!segmentIds.contains(next)) {
        errors.add(
          'a(z) "${s.id}" szakasz ismeretlen szakaszba folytatódik: "$next"',
        );
      }
    }
    if (spawns.isEmpty) errors.add('nincs megadva spawn (indulási pont)');
    for (final sp in spawns) {
      if (!segmentIds.contains(sp.segment)) {
        errors.add('spawn ismeretlen szakaszon: "${sp.segment}"');
      }
    }
    if (crashGoal <= 0) {
      errors.add('a goal.crashes értékének > 0-nak kell lennie');
    }
    if (width <= 0 || height <= 0) {
      errors.add('a pálya határai (bounds) > 0 kell legyenek');
    }
    for (final p in props) {
      errors.addAll(p.validate());
    }
    final segmentsById = {for (final s in segments) s.id: s};
    for (final c in crossovers) {
      errors.addAll(c.validate(segmentsById));
    }
    for (final g in gates) {
      errors.addAll(g.validate(segmentsById));
    }
    for (final z in zones) {
      errors.addAll(z.validate(segmentsById));
    }
    return errors;
  }

  static TrackSegment _segmentFromJson(Map<String, dynamic> json) {
    final endName = readOptionalString(json, 'end') ?? 'connected';
    final end = TrackEnd.values.asNameMap()[endName];
    if (end == null) {
      throw FormatException('Ismeretlen sínvég: "$endName"');
    }
    return TrackSegment(
      id: readRequiredString(json, 'id'),
      end: end,
      nextSegment: readOptionalString(json, 'nextSegment'),
      points: [
        for (final p in readOptionalList(json, 'points')) _pointFromJson(p),
      ],
    );
  }

  static Point<double> _pointFromJson(Object? raw) {
    final (x, y) = readPoint2D(raw, 'A "points" koordináta');
    return Point<double>(x, y);
  }
}
