import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/editor/editor_controller.dart';

/// Opens a modal dialog showing the exported layout JSON with clipboard copy.
Future<void> showEditorExportDialog(
  BuildContext context,
  EditorController controller,
) {
  final jsonText = controller.exportJson();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      title: const Text(
        'Pálya JSON export',
        style: TextStyle(color: Color(0xFFF1F5F9)),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: SelectableText(
            jsonText,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0xFFCBD5E1),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Bezárás'),
        ),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: jsonText));
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Másolás vágólapra'),
        ),
      ],
    ),
  );
}

/// Opens a modal dialog to paste and import a layout JSON string.
Future<void> showEditorImportDialog(
  BuildContext context,
  EditorController controller,
) async {
  final textController = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      title: const Text(
        'Pálya JSON betöltés',
        style: TextStyle(color: Color(0xFFF1F5F9)),
      ),
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: textController,
          maxLines: 10,
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Mégse'),
        ),
        FilledButton(
          onPressed: () {
            controller.importJson(textController.text);
            Navigator.of(ctx).pop();
          },
          child: const Text('Betöltés'),
        ),
      ],
    ),
  );
  textController.dispose();
}
