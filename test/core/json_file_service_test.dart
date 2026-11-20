import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_hot_imperfect_form_trams/core/game_log.dart';
import 'package:super_hot_imperfect_form_trams/core/json_file_service_io.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    GameLog.resetForTest();
    tempDir = Directory.systemTemp.createTempSync('json_file_service_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
    GameLog.resetForTest();
  });

  test('normalizeJsonFileName handles empty, plain, and .json names', () {
    expect(JsonFileService.normalizeJsonFileName(''), 'sajat_palya.json');
    expect(JsonFileService.normalizeJsonFileName('   '), 'sajat_palya.json');
    expect(JsonFileService.normalizeJsonFileName('palya'), 'palya.json');
    expect(JsonFileService.normalizeJsonFileName('palya.json'), 'palya.json');
    expect(JsonFileService.normalizeJsonFileName('palya.JSON'), 'palya.JSON');
  });

  test('saveJson and pickJson honour onSave / onPick overrides', () async {
    const expectedPick = (name: 'custom.json', contents: '{"id":"custom"}');
    String? savedName;
    String? savedContents;
    final service = JsonFileService(
      onSave: (name, contents) async {
        savedName = name;
        savedContents = contents;
        return name;
      },
      onPick: () async => expectedPick,
    );

    final out = await service.saveJson(
      suggestedName: 'my_map',
      contents: '{"a":1}',
    );
    expect(out, 'my_map.json');
    expect(savedName, 'my_map.json');
    expect(savedContents, '{"a":1}');
    expect(await service.pickJson(), expectedPick);
  });

  test(
    'saveJson appends .json and pickJson round-trips UTF-8 content',
    () async {
      final base = '${tempDir.path}${Platform.pathSeparator}palya_rviz';
      final service = JsonFileService.forTest(
        dialogRunner: ({required save, required fileName}) async =>
            save ? base : '$base.json',
      );

      final savedPath = await service.saveJson(
        suggestedName: 'palya_rviz',
        contents: '{"név":"Árvíztűrő tükörfúrógép"}',
      );
      expect(savedPath, '$base.json');
      expect(File('$base.json').existsSync(), isTrue);

      final picked = await service.pickJson();
      expect(picked, isNotNull);
      expect(picked?.name, 'palya_rviz.json');
      expect(picked?.contents, '{"név":"Árvíztűrő tükörfúrógép"}');
    },
  );

  test(
    'saveJson returns null and logs io when target is a directory',
    () async {
      final existingDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}blocked.json',
      )..createSync();
      final service = JsonFileService.forTest(
        dialogRunner: ({required save, required fileName}) async =>
            existingDir.path,
      );

      final result = await service.saveJson(
        suggestedName: 'ignored',
        contents: '{}',
      );
      expect(result, isNull);
      expect(
        GameLog.entries.any(
          (e) =>
              e.category == 'io' && e.message.contains('Failed to save JSON'),
        ),
        isTrue,
      );
    },
  );

  test('pickJson returns null and logs io when reading a directory', () async {
    final service = JsonFileService.forTest(
      dialogRunner: ({required save, required fileName}) async => tempDir.path,
    );

    final picked = await service.pickJson();
    expect(picked, isNull);
    expect(
      GameLog.entries.any(
        (e) => e.category == 'io' && e.message.contains('Failed to read JSON'),
      ),
      isTrue,
    );
  });

  test('pickJson returns null and logs io on invalid UTF-8 bytes', () async {
    final badFile = File('${tempDir.path}${Platform.pathSeparator}bad.json')
      ..writeAsBytesSync(const [0xFF, 0xFE]);
    final service = JsonFileService.forTest(
      dialogRunner: ({required save, required fileName}) async => badFile.path,
    );

    final picked = await service.pickJson();
    expect(picked, isNull);
    expect(
      GameLog.entries.any(
        (e) => e.category == 'io' && e.message.contains('Invalid UTF-8'),
      ),
      isTrue,
    );
  });
}
