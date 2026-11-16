import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_data.dart';
import 'package:super_hot_imperfect_form_trams/game/levels/level_repository.dart';
import 'package:super_hot_imperfect_form_trams/game/systems/track_graph.dart';
import 'package:super_hot_imperfect_form_trams/input/tram_controls.dart';

Map<String, dynamic> validLevel() => <String, dynamic>{
  'id': 't',
  'segments': <Map<String, dynamic>>[
    {'id': 'main', 'nextSegment': 'a'},
    {'id': 'a', 'end': 'river'},
    {'id': 'b', 'end': 'deadEnd'},
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

  test('buildGraph resolves segment transitions and hazards', () {
    final level = LevelData.fromJson(validLevel());
    final g = level.buildGraph();
    expect(g.advance('main').next, 'a');
    expect(g.advance('a').end, TrackEnd.river);
    expect(g.advance('b').end, TrackEnd.deadEnd);
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

  test(
    'spawn controls and start distance are parsed; unknown controls fail',
    () {
      final json = validLevel();
      (json['spawns'] as List)[0]
        ..['controls'] = 'wasd'
        ..['startDistance'] = 120;
      final spawn = LevelData.fromJson(json).spawns.first;
      expect(spawn.controls, TramControls.wasd);
      expect(spawn.startDistance, 120);

      (json['spawns'] as List)[0]['controls'] = 'joystick';
      expect(() => LevelData.fromJson(json), throwsFormatException);
    },
  );

  test('crossovers are parsed and checked against the segment geometry', () {
    final json = validLevel();
    (json['segments'] as List)[0]['points'] = [
      [0, 100],
      [0, -100],
    ];
    (json['segments'] as List)[1]['points'] = [
      [-100, 0],
      [100, 0],
    ];
    json['crossovers'] = [
      {
        'id': 'sw',
        'x': 0,
        'y': 0,
        'links': [
          {'from': 'main', 'to': 'a'},
        ],
      },
    ];
    final level = LevelData.fromJson(json);
    expect(level.crossovers.single.links.single.to, 'a');
    expect(level.crossovers.single.radius, 48);

    (json['crossovers'] as List)[0]['x'] = 50;
    (json['crossovers'] as List)[0]['links'] = [
      {'from': 'main', 'to': 'ghost'},
    ];
    expect(
      () => LevelData.fromJson(json),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('ghost'),
            contains('nincs rajta a(z) "main" szakaszon'),
          ),
        ),
      ),
    );
  });

  test('broken references are reported', () {
    final json = validLevel();
    (json['segments'] as List)[0]['nextSegment'] = 'nope';
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
