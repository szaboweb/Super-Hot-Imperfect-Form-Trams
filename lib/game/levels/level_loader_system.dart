import 'dart:math' as math;

import '../systems/crash_system.dart';
import '../systems/score_system.dart';
import '../systems/spawn_system.dart';
import '../systems/track_graph.dart';
import '../systems/track_path.dart';
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
    return (
      paths: paths,
      crossovers: crossovers,
      switches: switches,
      spawnSystem: SpawnSystem(level.spawns),
      scoreSystem: ScoreSystem(crashGoal: level.crashGoal),
      crashSystem: CrashSystem(graph: graph, paths: paths),
      aiSystem: TramAiSystem(graph: graph, paths: paths, switches: switches),
      hazards: _extractHazards(level.segments, paths),
    );
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
              from: paths[link.from]!,
              to: paths[link.to]!,
              center: data.center,
              radius: data.radius,
              movement: data.movement,
            ),
        ],
      ),
  ];

  static List<HazardPlacement> _extractHazards(
    List<TrackSegment> segments,
    Map<String, TrackPath> paths,
  ) {
    final incomingConnected = <String>{
      for (final s in segments)
        if (s.end == TrackEnd.connected && s.nextSegment != null)
          s.nextSegment!,
    };
    final hazards = <HazardPlacement>[];
    for (final seg in segments) {
      final path = paths[seg.id];
      if (path == null || path.isClosed) continue;
      if (seg.end != TrackEnd.connected) {
        hazards.add((
          kind: seg.end,
          position: path.positionAt(path.length),
          headingRad: path.headingAt(path.length),
        ));
      }
      if (!incomingConnected.contains(seg.id)) {
        hazards.add((
          kind: TrackEnd.deadEnd,
          position: path.positionAt(0),
          headingRad: path.headingAt(0) + math.pi,
        ));
      }
    }
    return hazards;
  }
}
