import 'dart:async';
import 'dart:js_interop';

/// File name and UTF-8 text content returned by [JsonFileService.pickJson].
typedef PickedJsonFile = ({String name, String contents});

@JS('document')
external _DomDocument get _document;

extension type _DomDocument._(JSObject _) implements JSObject {
  external _DomElement createElement(String tagName);
  external _DomElement? get body;
}

extension type _DomElement._(JSObject _) implements JSObject {
  external void setAttribute(String name, String value);
  external void click();
  external void remove();
  external void appendChild(_DomElement child);
  external void addEventListener(String type, JSFunction listener);
  external _DomFileList? get files;
}

extension type _DomFileList._(JSObject _) implements JSObject {
  external _DomFile? item(int index);
}

extension type _DomFile._(JSObject _) implements JSObject {
  external String get name;
  external JSPromise<JSString> text();
}

/// Web implementation saving via browser download and opening via `<input type="file">`.
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

  /// Triggers a browser download of [contents] using [suggestedName].
  Future<String?> saveJson({
    required String suggestedName,
    required String contents,
  }) async {
    final normalized = normalizeJsonFileName(suggestedName);
    final hook = onSave;
    if (hook != null) return hook(normalized, contents);
    final anchor = _document.createElement('a')
      ..setAttribute(
        'href',
        'data:application/json;charset=utf-8,${Uri.encodeComponent(contents)}',
      )
      ..setAttribute('download', normalized)
      ..setAttribute('style', 'display:none');
    _document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    return normalized;
  }

  /// Opens the browser file chooser for `.json` files and returns its text content.
  Future<PickedJsonFile?> pickJson() async {
    final hook = onPick;
    if (hook != null) return hook();
    final completer = Completer<PickedJsonFile?>();
    final input = _document.createElement('input')
      ..setAttribute('type', 'file')
      ..setAttribute('accept', '.json,application/json')
      ..setAttribute('style', 'display:none');

    void finish(PickedJsonFile? value) {
      if (!completer.isCompleted) completer.complete(value);
      input.remove();
    }

    input.addEventListener(
      'change',
      ((JSAny? _) {
        final file = input.files?.item(0);
        if (file == null) {
          finish(null);
          return;
        }
        file.text().toDart.then(
          (jsText) => finish((name: file.name, contents: jsText.toDart)),
          onError: (_) => finish(null),
        );
      }).toJS,
    );
    input.addEventListener('cancel', ((JSAny? _) => finish(null)).toJS);
    _document.body?.appendChild(input);
    input.click();
    return completer.future;
  }
}
