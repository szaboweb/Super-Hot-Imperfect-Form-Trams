import 'dart:convert';
import 'dart:io';

/// File name and UTF-8 text content returned by [JsonFileService.pickJson].
typedef PickedJsonFile = ({String name, String contents});

/// Desktop (`dart:io`) implementation opening native Save/Open `.json` dialogs.
class JsonFileService {
  /// Creates a file service with optional test/mock overrides [onSave] and [onPick].
  const JsonFileService({this.onSave, this.onPick});

  /// Optional override used when saving JSON text (primarily for tests).
  final Future<String?> Function(String suggestedName, String contents)? onSave;

  /// Optional override used when picking a JSON file (primarily for tests).
  final Future<PickedJsonFile?> Function()? onPick;

  /// Ensures [name] is non-empty and carries a `.json` file extension.
  static String normalizeJsonFileName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'sajat_palya.json';
    return trimmed.toLowerCase().endsWith('.json') ? trimmed : '$trimmed.json';
  }

  /// Opens a native save dialog and writes [contents] as UTF-8 `.json`, or `null` if cancelled.
  Future<String?> saveJson({
    required String suggestedName,
    required String contents,
  }) async {
    final normalized = normalizeJsonFileName(suggestedName);
    final hook = onSave;
    if (hook != null) return hook(normalized, contents);
    final chosenPath = await _runDialogPath(save: true, fileName: normalized);
    if (chosenPath == null || chosenPath.isEmpty) return null;
    final targetPath = chosenPath.toLowerCase().endsWith('.json')
        ? chosenPath
        : '$chosenPath.json';
    await File(targetPath).writeAsString(contents, encoding: utf8);
    return targetPath;
  }

  /// Opens a native file picker for `.json` files and returns its name and UTF-8 contents.
  Future<PickedJsonFile?> pickJson() async {
    final hook = onPick;
    if (hook != null) return hook();
    final chosenPath = await _runDialogPath(save: false, fileName: '');
    if (chosenPath == null || chosenPath.isEmpty) return null;
    final file = File(chosenPath);
    if (!file.existsSync()) return null;
    final contents = await file.readAsString(encoding: utf8);
    final baseName = chosenPath.split(RegExp(r'[/\\]')).last;
    return (name: baseName, contents: contents);
  }

  Future<String?> _runDialogPath({
    required bool save,
    required String fileName,
  }) async {
    if (Platform.isWindows) {
      return _runWindowsDialog(save: save, fileName: fileName);
    }
    if (Platform.isLinux) {
      return _runZenityDialog(save: save, fileName: fileName);
    }
    return null;
  }

  Future<String?> _runWindowsDialog({
    required bool save,
    required String fileName,
  }) async {
    final safeName = fileName.replaceAll("'", "''");
    final dialogClass = save
        ? 'System.Windows.Forms.SaveFileDialog'
        : 'System.Windows.Forms.OpenFileDialog';
    final nameProp = save ? "\$d.FileName = '$safeName'; " : '';
    final script =
        '[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new(\$false); '
        'Add-Type -AssemblyName System.Windows.Forms; '
        '\$d = New-Object $dialogClass; '
        "\$d.Filter = 'JSON (*.json)|*.json'; "
        '$nameProp'
        "if (\$d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { "
        '[Console]::Out.Write(\$d.FileName) }';
    final result = await Process.run(
      'powershell',
      ['-NoProfile', '-Sta', '-Command', script],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) return null;
    final out = (result.stdout as String).trim();
    return out.isEmpty ? null : out;
  }

  Future<String?> _runZenityDialog({
    required bool save,
    required String fileName,
  }) async {
    try {
      final args = [
        '--file-selection',
        if (save) '--save',
        if (save) '--confirm-overwrite',
        if (save && fileName.isNotEmpty) '--filename=$fileName',
        '--file-filter=JSON | *.json',
      ];
      final result = await Process.run(
        'zenity',
        args,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (result.exitCode != 0) return null;
      final out = (result.stdout as String).trim();
      return out.isEmpty ? null : out;
    } on ProcessException {
      return null;
    }
  }
}
