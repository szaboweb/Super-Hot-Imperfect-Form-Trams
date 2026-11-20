import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'game_log.dart';
import 'json_file_name.dart' as fn;

export 'json_file_name.dart' show PickedJsonFile;

/// Callback selecting a file system path for save or open dialogs.
typedef DialogPathRunner = Future<String?> Function({
  required bool save,
  required String fileName,
});

/// Desktop (`dart:io`) implementation opening native Save/Open `.json` dialogs.
class JsonFileService {
  /// Creates a file service with optional test/mock overrides [onSave] and [onPick].
  const JsonFileService({this.onSave, this.onPick}) : dialogRunner = null;

  /// Creates a desktop file service with an injectable [dialogRunner] for tests.
  @visibleForTesting
  const JsonFileService.forTest({this.onSave, this.onPick, this.dialogRunner});

  /// Optional override used when saving JSON text (primarily for tests).
  final Future<String?> Function(String suggestedName, String contents)? onSave;

  /// Optional override used when picking a JSON file (primarily for tests).
  final Future<fn.PickedJsonFile?> Function()? onPick;

  /// Test hook replacing native OS file dialogs.
  @visibleForTesting
  final DialogPathRunner? dialogRunner;

  /// Ensures [name] is non-empty and carries a `.json` file extension.
  static String normalizeJsonFileName(String name) =>
      fn.normalizeJsonFileName(name);

  /// Opens a native save dialog and writes [contents] as UTF-8 `.json`, or `null` if cancelled/failed.
  Future<String?> saveJson({
    required String suggestedName,
    required String contents,
  }) async {
    final normalized = normalizeJsonFileName(suggestedName);
    final hook = onSave;
    if (hook != null) return hook(normalized, contents);
    final runner = dialogRunner ?? _runDialogPath;
    final chosenPath = await runner(save: true, fileName: normalized);
    if (chosenPath == null || chosenPath.trim().isEmpty) return null;
    final targetPath = fn.normalizeJsonFileName(chosenPath);
    try {
      await File(targetPath).writeAsString(contents, encoding: utf8);
      return targetPath;
    } on FileSystemException catch (error) {
      GameLog.event('io', 'Failed to save JSON ($targetPath): $error');
      return null;
    }
  }

  /// Opens a native file picker for `.json` files and returns its name and UTF-8 contents.
  Future<fn.PickedJsonFile?> pickJson() async {
    final hook = onPick;
    if (hook != null) return hook();
    final runner = dialogRunner ?? _runDialogPath;
    final chosenPath = await runner(save: false, fileName: '');
    if (chosenPath == null || chosenPath.isEmpty) return null;
    if (FileSystemEntity.typeSync(chosenPath) ==
        FileSystemEntityType.notFound) {
      return null;
    }
    try {
      final bytes = await File(chosenPath).readAsBytes();
      final contents = utf8.decode(bytes);
      final baseName = chosenPath.split(RegExp(r'[/\\]')).last;
      return (name: baseName, contents: contents);
    } on FileSystemException catch (error) {
      GameLog.event('io', 'Failed to read JSON ($chosenPath): $error');
      return null;
    } on FormatException catch (error) {
      GameLog.event('io', 'Invalid UTF-8 in JSON ($chosenPath): $error');
      return null;
    }
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
    final dialogClass = save
        ? 'System.Windows.Forms.SaveFileDialog'
        : 'System.Windows.Forms.OpenFileDialog';
    final script =
        '[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new(\$false); '
        'Add-Type -AssemblyName System.Windows.Forms; '
        '\$d = New-Object $dialogClass; '
        "\$d.Filter = 'JSON (*.json)|*.json'; "
        r'if ($env:TRAM_JSON_FILENAME) { $d.FileName = $env:TRAM_JSON_FILENAME }; '
        r'if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { '
        r'[Console]::Out.Write($d.FileName) }';
    try {
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-Sta', '-Command', script],
        environment: save && fileName.isNotEmpty
            ? {'TRAM_JSON_FILENAME': fileName}
            : null,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (result.exitCode != 0) return null;
      final out = (result.stdout as String).trim();
      return out.isEmpty ? null : out;
    } on ProcessException catch (error) {
      GameLog.event('io', 'Windows file dialog unavailable: $error');
      return null;
    }
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
    } on ProcessException catch (error) {
      GameLog.event('io', 'Zenity file dialog unavailable: $error');
      return null;
    }
  }
}
