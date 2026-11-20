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

  group('fromJson throws FormatException on malformed field types', () {
    void expectMalformed(Map<String, dynamic> Function() mutate, String label) {
      final json = mutate();
      expect(
        () => LevelData.fromJson(json),
        throwsA(isA<FormatException>()),
        reason: label,
      );
    }

    test('top-level id, bounds, segments, spawns, and goal mismatches', () {
      expectMalformed(() => validLevel()..['id'] = 123, 'non-string id');
      expectMalformed(
        () => validLevel()..['bounds'] = 'wide',
        'non-map bounds',
      );
      expectMalformed(
        () => validLevel()..['segments'] = <String, dynamic>{},
        'non-list segments',
      );
      expectMalformed(() => validLevel()..['spawns'] = [42], 'non-map spawn');
      expectMalformed(
        () => validLevel()..['goal'] = {'crashes': 'one'},
        'non-num goal.crashes',
      );
    });

    test('nested segment, spawn, prop, crossover, gate, and zone errors', () {
      expectMalformed(() {
        final j = validLevel();
        (j['segments'] as List)[0] = {'id': 99};
        return j;
      }, 'segment id not string');
      expectMalformed(() {
        final j = validLevel();
        (j['spawns'] as List)[0] = {'segment': 'main', 'time': '0', 'speed': 1};
        return j;
      }, 'spawn time not num');
      expectMalformed(() {
        final j = validLevel();
        (j['spawns'] as List)[0] = {'segment': 'main', 'time': 0};
        return j;
      }, 'spawn speed missing');
      expectMalformed(
        () => validLevel()
          ..['props'] = [
            {'type': 5, 'x': 0, 'y': 0},
          ],
        'prop type not string',
      );
      expectMalformed(
        () => validLevel()
          ..['props'] = [
            {'type': 'signal', 'x': 'left', 'y': 0},
          ],
        'prop x not num',
      );
      expectMalformed(
        () => validLevel()
          ..['crossovers'] = [
            {'id': 'sw', 'x': 'zero', 'y': 0, 'links': []},
          ],
        'crossover x not num',
      );
      expectMalformed(
        () => validLevel()
          ..['crossovers'] = [
            {
              'id': 'sw',
              'x': 0,
              'y': 0,
              'links': ['bad'],
            },
          ],
        'crossover link not map',
      );
      expectMalformed(
        () => validLevel()
          ..['gates'] = [
            {'id': 7, 'x': 0, 'y': 0},
          ],
        'gate id not string',
      );
      expectMalformed(
        () => validLevel()
          ..['gates'] = [
            {'id': 'g1', 'x': 0, 'y': 'top'},
          ],
        'gate y not num',
      );
      expectMalformed(
        () => validLevel()
          ..['zones'] = [
            {'kind': 'ice', 'x': 'far', 'y': 0},
          ],
        'zone x not num',
      );
    });

    test('short or non-numeric coordinate lists', () {
      expectMalformed(() {
        final j = validLevel();
        (j['segments'] as List)[0]['points'] = [
          [10],
        ];
        return j;
      }, 'short segment point');
      expectMalformed(() {
        final j = validLevel();
        (j['segments'] as List)[0]['points'] = [
          ['a', 2],
        ];
        return j;
      }, 'non-numeric segment point');
      expectMalformed(
        () => validLevel()
          ..['crossovers'] = [
            {
              'id': 'sw',
              'x': 0,
              'y': 0,
              'signalOffset': [1],
              'links': [],
            },
          ],
        'short signalOffset list',
      );
    });
  });
}
