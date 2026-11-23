import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

final Uint8List photoBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEElEQVR4nGMQK80EIgYIBQAZcgPRDk0bKwAAAABJRU5ErkJggg==',
);

Map<String, Object?> catJson(String id) => {
  'id': id,
  'url': 'https://images.example.test/$id.png',
  'breeds': [
    {
      'name': 'Abyssinian',
      'origin': 'Egypt',
      'temperament': 'Active, Curious',
      'description': 'A curious and active cat.',
    },
  ],
};

http.Response catResponse(String id) => http.Response(
  jsonEncode([catJson(id)]),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
