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
                (throw FormatException('Unknown controls "$controlsName"')),
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
    required this._switches,
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
      switches: [
        for (final s in (json['switches'] as List? ?? const []))
          _switchFromJson(s as Map<String, dynamic>),
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
      throw FormatException('Invalid level "$id":\n- ${errors.join('\n- ')}');
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
  final List<SwitchNode> _switches;

  /// Fresh graph with every switch in its initial position.
  TrackGraph buildGraph() => TrackGraph(
    segments: segments,
    switches: [
      for (final s in _switches)
        SwitchNode(
          id: s.id,
          straight: s.straight,
          diverging: s.diverging,
          diverge: s.diverge,
        ),
    ],
  );

  List<String> validate() {
    final errors = <String>[];
    final segmentIds = <String>{};
    for (final s in segments) {
      if (!segmentIds.add(s.id)) errors.add('duplicate segment "${s.id}"');
      if (s.points.length == 1) {
        errors.add('segment "${s.id}" geometry needs at least 2 points');
      }
    }
    final switchIds = <String>{};
    for (final s in _switches) {
      if (!switchIds.add(s.id)) errors.add('duplicate switch "${s.id}"');
      for (final target in [s.straight, s.diverging]) {
        if (!segmentIds.contains(target)) {
          errors.add('switch "${s.id}" points to unknown segment "$target"');
        }
      }
    }
    for (final s in segments) {
      if (s.end != TrackEnd.connected) continue;
      final hasSwitch = s.nextSwitch != null;
      final hasSegment = s.nextSegment != null;
      if (hasSwitch == hasSegment) {
        errors.add(
          'connected segment "${s.id}" needs exactly one of '
          'nextSwitch / nextSegment',
        );
      } else if (hasSwitch && !switchIds.contains(s.nextSwitch)) {
        errors.add('segment "${s.id}" uses unknown switch "${s.nextSwitch}"');
      } else if (hasSegment && !segmentIds.contains(s.nextSegment)) {
        errors.add('segment "${s.id}" continues to unknown "${s.nextSegment}"');
      }
    }
    if (spawns.isEmpty) errors.add('no spawns');
    for (final sp in spawns) {
      if (!segmentIds.contains(sp.segment)) {
        errors.add('spawn on unknown segment "${sp.segment}"');
      }
    }
    if (crashGoal <= 0) errors.add('goal.crashes must be > 0');
    if (width <= 0 || height <= 0) errors.add('bounds must be > 0');
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
      throw FormatException('Unknown track end "$endName"');
    }
    return TrackSegment(
      id: json['id'] as String,
      end: end,
      nextSwitch: json['nextSwitch'] as String?,
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

  static SwitchNode _switchFromJson(Map<String, dynamic> json) => SwitchNode(
    id: json['id'] as String,
    straight: json['straight'] as String,
    diverging: json['diverging'] as String,
    diverge: json['diverge'] as bool? ?? false,
  );
}
