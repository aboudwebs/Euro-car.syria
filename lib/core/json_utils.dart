// Defensive JSON readers. The API returns numeric columns as numbers or as strings depending on the column
// type, and a missing field must never crash a screen.

double? asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}

int? asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    final String text = value.trim();
    return int.tryParse(text) ?? double.tryParse(text)?.toInt();
  }
  return null;
}

String asString(Object? value, [String fallback = '']) {
  if (value == null) {
    return fallback;
  }
  return value.toString();
}

/// Null for null and for empty text.
String? asOptionalString(Object? value) {
  if (value == null) {
    return null;
  }
  final String text = value.toString();
  return text.isEmpty ? null : text;
}

DateTime? asDate(Object? value) {
  if (value is! String) {
    return null;
  }
  final DateTime? parsed = DateTime.tryParse(value);
  return parsed?.toLocal();
}

Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

List<Object?> asList(Object? value) {
  if (value is List) {
    return List<Object?>.from(value);
  }
  return <Object?>[];
}
