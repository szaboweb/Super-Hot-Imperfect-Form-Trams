import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/json_file_service.dart';
import '../../game/editor/editor_controller.dart';
import 'overlay_window.dart';

/// Opens a modal dialog to save the layout as a `.json` file or copy it to the clipboard.
Future<void> showEditorExportDialog(
  BuildContext context,
  EditorController controller, {
  JsonFileService fileService = const JsonFileService(),
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) =>
        _EditorExportDialog(controller: controller, fileService: fileService),
  );
}

/// Opens a modal dialog to load a layout from a `.json` file or pasted JSON text.
Future<void> showEditorImportDialog(
  BuildContext context,
  EditorController controller, {
  JsonFileService fileService = const JsonFileService(),
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) =>
        _EditorImportDialog(controller: controller, fileService: fileService),
  );
}

class _EditorDialogFrame extends StatelessWidget {
  const _EditorDialogFrame({
    required this.title,
    required this.icon,
    required this.body,
    required this.actions,
  });

  final String title;
  final IconData icon;
  final List<Widget> body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: OverlayWindow(
        title: title,
        icon: icon,
        width: 520,
        maxHeight: 440,
        backgroundColor: const Color(0xF50F172A),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...body,
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorExportDialog extends StatefulWidget {
  const _EditorExportDialog({
    required this.controller,
    required this.fileService,
  });

  final EditorController controller;
  final JsonFileService fileService;

  @override
  State<_EditorExportDialog> createState() => _EditorExportDialogState();
}

class _EditorExportDialogState extends State<_EditorExportDialog> {
  final TextEditingController _nameController = TextEditingController(
    text: 'sajat_palya.json',
  );
  late final String _editorJson = widget.controller.exportJson();
  late final String? _playableJson = widget.controller
      .exportPlayableLevelJson();
  bool _exportPlayable = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _activeJson =>
      (_exportPlayable && _playableJson != null) ? _playableJson : _editorJson;

  Future<void> _saveToFile() async {
    final saved = await widget.fileService.saveJson(
      suggestedName: _nameController.text,
      contents: _activeJson,
    );
    if (saved != null) {
      widget.controller.showStatus('Pálya fájlba mentve: $saved');
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _activeJson));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return _EditorDialogFrame(
      title: 'Pálya mentése / JSON export',
      icon: Icons.file_download_outlined,
      body: [
        TextField(
          controller: _nameController,
          style: const TextStyle(color: Color(0xFFF1F5F9)),
          decoration: const InputDecoration(
            labelText: 'Fájlnév (.json)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Szerkesztő-terv (.json)'),
              selected: !_exportPlayable,
              onSelected: (_) => setState(() => _exportPlayable = false),
            ),
            ChoiceChip(
              label: const Text('Játszható pálya (.json)'),
              selected: _exportPlayable,
              onSelected: _playableJson == null
                  ? null
                  : (_) => setState(() => _exportPlayable = true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _JsonPreviewBox(text: _activeJson),
      ],
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Bezárás'),
        ),
        OutlinedButton.icon(
          onPressed: _copyToClipboard,
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Másolás vágólapra'),
        ),
        FilledButton.icon(
          onPressed: _saveToFile,
          icon: const Icon(Icons.save_alt, size: 16),
          label: const Text('Mentés fájlba (.json)'),
        ),
      ],
    );
  }
}

class _JsonPreviewBox extends StatelessWidget {
  const _JsonPreviewBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 140),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          text,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
  }
}

class _EditorImportDialog extends StatefulWidget {
  const _EditorImportDialog({
    required this.controller,
    required this.fileService,
  });

  final EditorController controller;
  final JsonFileService fileService;

  @override
  State<_EditorImportDialog> createState() => _EditorImportDialogState();
}

class _EditorImportDialogState extends State<_EditorImportDialog> {
  final TextEditingController _textController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final picked = await widget.fileService.pickJson();
    if (picked == null) return;
    if (widget.controller.importJson(picked.contents)) {
      widget.controller.showStatus('Betöltve fájlból: ${picked.name}');
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (!mounted) return;
    setState(() {
      _errorText = 'A kiválasztott fájl nem érvényes szerkesztő-terv JSON.';
    });
  }

  void _importPastedText() {
    if (widget.controller.importJson(_textController.text)) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _errorText = 'A beillesztett szöveg nem érvényes terv JSON.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return _EditorDialogFrame(
      title: 'Pálya betöltése (.json)',
      icon: Icons.folder_open,
      body: [
        FilledButton.icon(
          onPressed: _pickFile,
          icon: const Icon(Icons.folder_open, size: 18),
          label: const Text('Fájl kiválasztása (.json)...'),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 10),
          Text(
            _errorText!,
            style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
          ),
        ],
        const SizedBox(height: 14),
        const Text(
          'vagy illeszd be a JSON szöveget:',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _textController,
          maxLines: 8,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Color(0xFFF1F5F9),
          ),
          decoration: const InputDecoration(
            hintText: 'Illeszd be a pálya JSON szövegét...',
            hintStyle: TextStyle(color: Color(0xFF64748B)),
            border: OutlineInputBorder(),
          ),
        ),
      ],
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Mégse'),
        ),
        FilledButton(
          onPressed: _importPastedText,
          child: const Text('Betöltés szövegből'),
        ),
      ],
    );
  }
}
