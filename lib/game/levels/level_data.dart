import 'dart:math' show Point;

import '../../input/tram_controls.dart';
import '../systems/track_graph.dart';
import 'crossover_data.dart';
import 'prop_data.dart';

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
    final controlsName = json['controls'] as String?;
    return SpawnData(
      segment: json['segment'] as String,
      time: (json['time'] as num).toDouble(),
      speed: (json['speed'] as num).toDouble(),
      controls: controlsName == null
          ? null
          : TramControls.values.asNameMap()[controlsName] ??
                (throw FormatException(
                  'Ismeretlen irányítás: "$controlsName"',
                )),
      startDistance: (json['startDistance'] as num?)?.toDouble() ?? 0,
      color: (json['color'] as num?)?.toInt() ?? 0xFFE4572E,
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
    required this.city,
    required this.tileSize,
    required this.width,
    required this.height,
    required this.segments,
    required this.spawns,
    required this.props,
    required this.crossovers,
    required this.crashGoal,
  });

  /// Throws [FormatException] listing every problem found in [json].
  factory LevelData.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '<unknown>';
    final bounds = json['bounds'] as Map<String, dynamic>?;
    final level = LevelData._(
      id: id,
      city: json['city'] as String? ?? '',
      tileSize: (json['tileSize'] as num?)?.toInt() ?? 64,
      width: (bounds?['width'] as num?)?.toDouble() ?? 1040,
      height: (bounds?['height'] as num?)?.toDouble() ?? 680,
      segments: [
        for (final s in (json['segments'] as List? ?? const []))
          _segmentFromJson(s as Map<String, dynamic>),
      ],
      spawns: [
        for (final s in (json['spawns'] as List? ?? const []))
          SpawnData.fromJson(s as Map<String, dynamic>),
      ],
      props: [
        for (final p in (json['props'] as List? ?? const []))
          PropData.fromJson(p as Map<String, dynamic>),
      ],
      crossovers: [
        for (final c in (json['crossovers'] as List? ?? const []))
          CrossoverData.fromJson(c as Map<String, dynamic>),
      ],
      crashGoal: ((json['goal'] as Map?)?['crashes'] as num?)?.toInt() ?? 0,
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
  final String city;
  final int tileSize;

  /// Playable area size in world px, centred on the origin.
  final double width;
  final double height;
  final List<TrackSegment> segments;
  final List<SpawnData> spawns;
  final List<PropData> props;

  /// L-shaped switches between loops (flipped with the owner's SHIFT key).
  final List<CrossoverData> crossovers;
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
    return errors;
  }

  static TrackSegment _segmentFromJson(Map<String, dynamic> json) {
    final endName = json['end'] as String? ?? 'connected';
    final end = TrackEnd.values.asNameMap()[endName];
    if (end == null) {
      throw FormatException('Ismeretlen sínvég: "$endName"');
    }
    return TrackSegment(
      id: json['id'] as String,
      end: end,
      nextSegment: json['nextSegment'] as String?,
      points: [
        for (final p in (json['points'] as List? ?? const []))
          Point<double>(
            ((p as List)[0] as num).toDouble(),
            (p[1] as num).toDouble(),
          ),
      ],
    );
  }
}
