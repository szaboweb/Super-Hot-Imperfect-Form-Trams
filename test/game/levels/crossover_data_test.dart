import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/crossover_data.dart';

void main() {
  Map<String, dynamic> json([Object? shape]) => {
    'id': 'sw',
    'x': 0,
    'y': 0,
    'links': <Map<String, String>>[],
    'platformShape': ?shape,
  };

  test('platformShape defaults to circle', () {
    expect(CrossoverData.fromJson(json()).shape, PlatformShape.circle);
  });

  test('platformShape parses every shape name', () {
    for (final s in PlatformShape.values) {
      expect(CrossoverData.fromJson(json(s.name)).shape, s);
    }
  });

  test('unknown platformShape falls back to circle', () {
    expect(CrossoverData.fromJson(json('hexagon')).shape, PlatformShape.circle);
  });
}
