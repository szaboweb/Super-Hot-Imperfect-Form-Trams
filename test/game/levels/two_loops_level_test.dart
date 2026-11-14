import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/crossover_data.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_data.dart';

void main() {
  test('example_two_loops loads and has all three platform kinds', () {
    final json = jsonDecode(
      File('assets/data/levels/example_two_loops.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final level = LevelData.fromJson(json);
    expect(level.validate(), isEmpty);
    final shapes = level.crossovers.map((c) => c.shape).toSet();
    expect(shapes, {
      PlatformShape.triangle,
      PlatformShape.circle,
      PlatformShape.rectangle,
    });
  });
}
