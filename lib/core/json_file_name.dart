/// File name and UTF-8 text content returned by JSON file pickers.
typedef PickedJsonFile = ({String name, String contents});

/// Ensures [name] is non-empty and carries a `.json` file extension.
String normalizeJsonFileName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'sajat_palya.json';
  return trimmed.toLowerCase().endsWith('.json') ? trimmed : '$trimmed.json';
}
