class Breed {
  const Breed({
    required this.name,
    this.origin,
    this.temperament,
    this.description,
  });

  factory Breed.fromJson(Map<String, dynamic> json) => Breed(
    name: _requiredText(json, 'name'),
    origin: _optionalText(json, 'origin'),
    temperament: _optionalText(json, 'temperament'),
    description: _optionalText(json, 'description'),
  );

  final String name;
  final String? origin;
  final String? temperament;
  final String? description;
}

class Cat {
  const Cat({required this.id, required this.imageUrl, required this.breed});

  factory Cat.fromJson(Map<String, dynamic> json) {
    final url = Uri.tryParse(_requiredText(json, 'url'));
    if (url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty) {
      throw const FormatException('Invalid image URL');
    }
    final breeds = json['breeds'];
    if (breeds is! List || breeds.isEmpty) {
      throw const MissingBreedException();
    }
    final Object? breed = breeds.first;
    if (breed is! Map<String, dynamic>) {
      throw const FormatException('Invalid breed');
    }
    return Cat(
      id: _requiredText(json, 'id'),
      imageUrl: url,
      breed: Breed.fromJson(breed),
    );
  }

  final String id;
  final Uri imageUrl;
  final Breed breed;
}

class MissingBreedException implements Exception {
  const MissingBreedException();
}

String _requiredText(Map<String, dynamic> json, String key) {
  final text = _optionalText(json, key);
  if (text == null) throw FormatException('Missing $key');
  return text;
}

String? _optionalText(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('Invalid $key');
  final text = value.trim();
  return text.isEmpty ? null : text;
}
