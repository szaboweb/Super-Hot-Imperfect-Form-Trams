import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/crash_system.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/score_system.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_graph.dart';

void main() {
  CrashEvent event(int n) => CrashEvent(
    tramIndices: [n],
    hazard: TrackEnd.deadEnd,
    position: const math.Point(0, 0),
    description: 'crash $n',
  );

  test('record returns true only when goal transitions false -> true', () {
    final score = ScoreSystem(crashGoal: 3);
    expect(score.crashCount, 0);
    expect(score.isGoalMet, isFalse);

    expect(score.record(event(1)), isFalse);
    expect(score.crashCount, 1);
    expect(score.isGoalMet, isFalse);

    expect(score.record(event(2)), isFalse);
    expect(score.crashCount, 2);
    expect(score.isGoalMet, isFalse);

    expect(score.record(event(3)), isTrue);
    expect(score.crashCount, 3);
    expect(score.isGoalMet, isTrue);

    expect(score.record(event(4)), isFalse);
    expect(score.crashCount, 4);
    expect(score.isGoalMet, isTrue);
    expect(score.events.map((e) => e.description).toList(), [
      'crash 1',
      'crash 2',
      'crash 3',
      'crash 4',
    ]);
  });

  test('goal of 1 triggers on the very first crash only', () {
    final score = ScoreSystem(crashGoal: 1);
    expect(score.record(event(1)), isTrue);
    expect(score.isGoalMet, isTrue);
    expect(score.record(event(2)), isFalse);
  });

  test('non-positive crashGoal never marks goal as met', () {
    final zero = ScoreSystem(crashGoal: 0);
    expect(zero.record(event(1)), isFalse);
    expect(zero.isGoalMet, isFalse);
    expect(zero.crashCount, 1);

    final negative = ScoreSystem(crashGoal: -2);
    expect(negative.record(event(1)), isFalse);
    expect(negative.isGoalMet, isFalse);
  });
}
