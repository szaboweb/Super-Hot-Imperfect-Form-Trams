import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_data.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_repository.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_graph.dart';

Map<String, dynamic> validLevel() => {
  'id': 't',
  'segments': [
    {'id': 'main', 'nextSwitch': 'sw'},
    {'id': 'a', 'end': 'river'},
    {'id': 'b', 'end': 'deadEnd'},
  ],
  'switches': [
    {'id': 'sw', 'straight': 'a', 'diverging': 'b'},
  ],
  'spawns': [
    {'segment': 'main', 'time': 0, 'speed': 200},
  ],
  'goal': {'crashes': 1},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every level in the manifest loads and validates', () async {
    final levels = await LevelRepository().loadAll();
    expect(levels, isNotEmpty);
  });

  test('buildGraph returns fresh switch state each time', () {
    final level = LevelData.fromJson(validLevel());
    final g1 = level.buildGraph()..switches['sw']!.toggle();
    expect(g1.advance('main').next, 'b');
    expect(level.buildGraph().advance('main').next, 'a');
    expect(level.buildGraph().advance('a').end, TrackEnd.river);
  });

  test('props are parsed and invalid ones are reported', () {
    final json = validLevel()
      ..['props'] = [
        {'type': 'channel', 'x': 0, 'y': 10, 'width': 100, 'height': 20},
        {'type': 'signal', 'x': 5, 'y': 5, 'state': 'red'},
      ];
    final level = LevelData.fromJson(json);
    expect(level.props.map((p) => p.type.name), ['channel', 'signal']);

    json['props'] = [
      {'type': 'building', 'x': 0, 'y': 0},
      {'type': 'signal', 'x': 1, 'y': 1, 'state': 'blue'},
    ];
    expect(
      () => LevelData.fromJson(json),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          allOf(contains('building'), contains('blue')),
        ),
      ),
    );
  });

  test('broken references are reported', () {
    final json = validLevel();
    (json['switches'] as List)[0]['diverging'] = 'nope';
    (json['spawns'] as List)[0]['segment'] = 'ghost';
    expect(
      () => LevelData.fromJson(json),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          allOf(contains('nope'), contains('ghost')),
        ),
      ),
    );
  });
}
