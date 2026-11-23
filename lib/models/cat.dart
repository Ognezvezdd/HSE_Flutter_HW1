import 'breed.dart';
import 'json_fields.dart';

class Cat {
  const Cat({required this.id, required this.imageUrl, required this.breed});

  factory Cat.fromJson(Map<String, dynamic> json) {
    final url = Uri.tryParse(requiredText(json, 'url'));
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
      id: requiredText(json, 'id'),
      imageUrl: url,
      breed: Breed.fromJson(breed),
    );
  }

  final String id;
  final Uri imageUrl;
  final Breed breed;

  Map<String, Object?> toJson() => {
    'id': id,
    'url': imageUrl.toString(),
    'breeds': [breed.toJson()],
  };
}

class MissingBreedException implements Exception {
  const MissingBreedException();
}
