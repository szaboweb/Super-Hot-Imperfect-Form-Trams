import 'json_file_name.dart' as fn;

export 'json_file_name.dart' show PickedJsonFile;

/// Cross-platform service saving and opening `.json` files from disk.
class JsonFileService {
  /// Creates a file service with optional test/mock overrides [onSave] and [onPick].
  const JsonFileService({this.onSave, this.onPick});

  /// Optional override used when saving JSON text (primarily for tests).
  final Future<String?> Function(String suggestedName, String contents)? onSave;

  /// Optional override used when picking a JSON file (primarily for tests).
  final Future<fn.PickedJsonFile?> Function()? onPick;

  /// Ensures [name] is non-empty and carries a `.json` file extension.
  static String normalizeJsonFileName(String name) =>
      fn.normalizeJsonFileName(name);

  /// Saves [contents] under [suggestedName], returning the saved name/path or `null` if cancelled.
  Future<String?> saveJson({
    required String suggestedName,
    required String contents,
  }) async {
    final normalized = normalizeJsonFileName(suggestedName);
    final hook = onSave;
    if (hook != null) return hook(normalized, contents);
    return null;
  }

  /// Prompts the user to pick a `.json` file, returning `null` if cancelled.
  Future<fn.PickedJsonFile?> pickJson() async {
    final hook = onPick;
    if (hook != null) return hook();
    return null;
  }
}
