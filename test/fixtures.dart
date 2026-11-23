import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:cat_tinder/models/feed_snapshot.dart';
import 'package:cat_tinder/services/feed_store.dart';

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

class MemoryFeedStore implements FeedStore {
  MemoryFeedStore({FeedSnapshot initial = const FeedSnapshot()})
    : raw = jsonEncode(initial.toJson());

  String raw;
  bool failReads = false;
  bool failWrites = false;
  int writes = 0;

  @override
  Future<FeedSnapshot> read() async {
    if (failReads) throw const FeedStorageException('Reading failed');
    try {
      return FeedSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      throw const FeedStorageException('Saved feed is corrupt', canReset: true);
    }
  }

  @override
  Future<void> write(FeedSnapshot snapshot) async {
    if (failWrites) throw const FeedStorageException('Writing failed');
    raw = jsonEncode(snapshot.toJson());
    writes++;
  }
}
