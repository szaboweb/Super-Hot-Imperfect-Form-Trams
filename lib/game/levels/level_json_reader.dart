// Type-safe JSON field readers that consistently throw [FormatException]
// instead of raw [TypeError] or [RangeError] when level data is malformed.

/// Reads a required non-null [String] field from [json].
String readRequiredString(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is String) return raw;
  throw FormatException('A "$key" mezőnek szövegnek (String) kell lennie.');
}

/// Reads an optional [String] field from [json], returning `null` if omitted.
String? readOptionalString(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw == null) return null;
  if (raw is String) return raw;
  throw FormatException('A "$key" mezőnek szövegnek (String) kell lennie.');
}

/// Reads a required numeric field from [json] as a [double].
double readRequiredDouble(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is num) return raw.toDouble();
  throw FormatException('A "$key" mezőnek számnak (num) kell lennie.');
}

/// Reads an optional numeric field from [json] as a [double], using [fallback] if omitted.
double readOptionalDouble(
  Map<String, dynamic> json,
  String key,
  double fallback,
) {
  final raw = json[key];
  if (raw == null) return fallback;
  if (raw is num) return raw.toDouble();
  throw FormatException('A "$key" mezőnek számnak (num) kell lennie.');
}

/// Reads an optional numeric field from [json] as an [int], using [fallback] if omitted.
int readOptionalInt(Map<String, dynamic> json, String key, int fallback) {
  final raw = json[key];
  if (raw == null) return fallback;
  if (raw is num) return raw.toInt();
  throw FormatException('A "$key" mezőnek számnak (num) kell lennie.');
}

/// Reads an optional [List] field from [json], returning `const []` if omitted.
List<Object?> readOptionalList(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw == null) return const [];
  if (raw is List) return raw;
  throw FormatException('A "$key" mezőnek listának (List) kell lennie.');
}

/// Reads an optional [Map<String, dynamic>] field from [json], or `null` if omitted.
Map<String, dynamic>? readOptionalMap(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw == null) return null;
  return readMapItem(raw, 'a(z) "$key" mező');
}

/// Validates that [raw] is a string-keyed [Map] for [context].
Map<String, dynamic> readMapItem(Object? raw, String context) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map && raw.keys.every((k) => k is String)) {
    return raw.cast<String, dynamic>();
  }
  throw FormatException('$context objektumnak (Map) kell lennie.');
}

/// Reads a 2-element numeric coordinate list `[x, y]` for [context].
(double, double) readPoint2D(Object? raw, String context) {
  if (raw is! List || raw.length < 2) {
    throw FormatException('$context legalább 2 elemű számlista kell legyen.');
  }
  final x = raw[0];
  final y = raw[1];
  if (x is! num || y is! num) {
    throw FormatException('$context elemeinek számnak kell lenniük.');
  }
  return (x.toDouble(), y.toDouble());
}

/// Reads an optional `[x, y]` coordinate pair from [json], or `null` if omitted.
(double, double)? readOptionalPoint2D(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw == null) return null;
  return readPoint2D(raw, 'A(z) "$key" koordináta');
}
