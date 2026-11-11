import 'dart:convert';

import 'package:flutter/services.dart';

import 'level_data.dart';

/// Loads levels listed in the manifest. Adding a level = new JSON file plus
/// one entry in `levels.json`; no code changes.
class LevelRepository {
  LevelRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const String basePath = 'assets/data/levels';

  final AssetBundle _bundle;

  Future<List<LevelData>> loadAll() async {
    final manifest = jsonDecode(
      await _bundle.loadString('$basePath/levels.json'),
    ) as Map<String, dynamic>;
    final ids = (manifest['levels'] as List).cast<String>();
    return [for (final id in ids) await load(id)];
  }

  Future<LevelData> load(String id) async {
    final json = jsonDecode(
      await _bundle.loadString('$basePath/$id.json'),
    ) as Map<String, dynamic>;
    return LevelData.fromJson(json);
  }
}
