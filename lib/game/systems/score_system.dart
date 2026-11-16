import 'crash_system.dart';

/// Tracks recorded [CrashEvent]s against a level's [crashGoal].
class ScoreSystem {
  /// Creates a score tracker targeting [crashGoal] crashes to clear the level.
  ScoreSystem({required this.crashGoal});

  /// Number of crashes required to complete the level (`<= 0` disables goal).
  final int crashGoal;

  /// Recorded crash events in chronological order.
  final List<CrashEvent> events = [];

  /// Total number of crashes recorded so far.
  int get crashCount => events.length;

  /// Whether a positive [crashGoal] has been reached.
  bool get isGoalMet => crashGoal > 0 && crashCount >= crashGoal;

  /// Records [event] and returns `true` only on the call that first satisfies [isGoalMet].
  bool record(CrashEvent event) {
    final wasMet = isGoalMet;
    events.add(event);
    return !wasMet && isGoalMet;
  }
}
