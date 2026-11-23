String requiredText(Map<String, dynamic> json, String key) {
  final text = optionalText(json, key);
  if (text == null) throw FormatException('Missing $key');
  return text;
}

String? optionalText(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('Invalid $key');
  final text = value.trim();
  return text.isEmpty ? null : text;
}
