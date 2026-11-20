import 'dart:math' as math;

import '../systems/crash_system.dart';
import '../systems/gate_system.dart';
import '../systems/score_system.dart';
import '../systems/spawn_system.dart';
import '../systems/track_graph.dart';
import '../systems/track_path.dart';
import '../systems/track_zone_system.dart';
import '../systems/tram_ai_system.dart';
import '../systems/turntable_switch_system.dart';
import '../systems/turntable_turn.dart';
import '../systems/turntable_turn_builder.dart';
import 'crossover_data.dart';
import 'level_data.dart';

/// Placement of an open-track end hazard in world coordinates.
typedef HazardPlacement = ({
  TrackEnd kind,
  math.Point<double> position,
  double headingRad,
});

/// Linked turntable crossover definition paired with its built [TurntableTurn]s.
typedef LoadedCrossover = ({CrossoverData data, List<TurntableTurn> turns});

/// Pure-Dart runtime systems and geometry assembled from a [LevelData].
typedef LoadedLevelRuntime = ({
  Map<String, TrackPath> paths,
  List<LoadedCrossover> crossovers,
  TurntableSwitchSystem switches,
  SpawnSystem spawnSystem,
  ScoreSystem scoreSystem,
  CrashSystem crashSystem,
  TramAiSystem aiSystem,
  GateSystem gateSystem,
  TrackZoneSystem zoneSystem,
  List<HazardPlacement> hazards,
});

/// Assembles pure-Dart runtime graphs, paths, hazards, and systems from [LevelData].
class LevelLoaderSystem {
  /// Creates a stateless pure-Dart level runtime loader.
  const LevelLoaderSystem();

  /// Builds all pure-Dart paths, turntables, hazards, and gameplay systems for [level].
  LoadedLevelRuntime load(LevelData level) {
    final graph = level.buildGraph();
    final paths = <String, TrackPath>{
      for (final s in level.segments)
        if (s.points.length >= 2) s.id: TrackPath(s.points, name: s.id),
    };
    final crossovers = _buildCrossovers(level.crossovers, paths);
    final switches = TurntableSwitchSystem([
      for (final c in crossovers) ...c.turns,
    ]);
    final gateSystem = GateSystem(gates: level.gates, paths: paths);
    final zoneSystem = TrackZoneSystem(zones: level.zones, paths: paths);
    return (
      paths: paths,
      crossovers: crossovers,
      switches: switches,
      spawnSystem: SpawnSystem(level.spawns),
      scoreSystem: ScoreSystem(crashGoal: level.crashGoal),
      crashSystem: CrashSystem(graph: graph, paths: paths),
      aiSystem: TramAiSystem(
        graph: graph,
        paths: paths,
        switches: switches,
        gates: gateSystem,
      ),
      gateSystem: gateSystem,
      zoneSystem: zoneSystem,
      hazards: _extractHazards(level.segments, paths, level.crossovers),
    );
  }

  static TrackPath _requirePath(
    Map<String, TrackPath> paths,
    String segmentId,
    String crossoverId,
  ) {
    final path = paths[segmentId];
    if (path == null) {
      throw StateError(
        'Missing path "$segmentId" for crossover "$crossoverId"',
      );
    }
    return path;
  }

  static List<LoadedCrossover> _buildCrossovers(
    List<CrossoverData> crossovers,
    Map<String, TrackPath> paths,
  ) => [
    for (final data in crossovers)
      (
        data: data,
        turns: [
          for (final link in data.links)
            ...TurntableTurnBuilder.buildAll(
              from: _requirePath(paths, link.from, data.id),
              to: _requirePath(paths, link.to, data.id),
              center: data.center,
              radius: data.radius,
              movement: data.movement,
              stemPoint: data.stemPoint,
              forward: data.forward,
            ),
        ],
      ),
  ];

  static List<HazardPlacement> _extractHazards(
    List<TrackSegment> segments,
    Map<String, TrackPath> paths,
    List<CrossoverData> crossovers,
  ) {
    bool atCrossover(math.Point<double> pos) =>
        crossovers.any((c) => c.center.distanceTo(pos) <= 4.0);

    final incomingConnected = <String>{
      for (final s in segments)
        if (s.nextSegment case final next? when s.end == TrackEnd.connected)
          next,
    };
    final hazards = <HazardPlacement>[];
    for (final seg in segments) {
      final path = paths[seg.id];
      if (path == null || path.isClosed) continue;
      final endPos = path.positionAt(path.length);
      if (seg.end != TrackEnd.connected && !atCrossover(endPos)) {
        hazards.add((
          kind: seg.end,
          position: endPos,
          headingRad: path.headingAt(path.length),
        ));
      }
      final startPos = path.positionAt(0);
      if (!incomingConnected.contains(seg.id) && !atCrossover(startPos)) {
        hazards.add((
          kind: TrackEnd.deadEnd,
          position: startPos,
          headingRad: path.headingAt(0) + math.pi,
        ));
      }
    }
    return hazards;
  }
}
