import 'dart:convert';

import 'package:cat_tinder/models/cat.dart';
import 'package:cat_tinder/models/feed_snapshot.dart';
import 'package:cat_tinder/services/feed_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fixtures.dart';

final class FailingPreferences extends InMemorySharedPreferencesAsync {
  FailingPreferences() : super.empty();

  bool failReads = false;
  bool failWrites = false;

  @override
  Future<String?> getString(
    String key,
    SharedPreferencesOptions options,
  ) async {
    if (failReads) throw StateError('Storage unavailable');
    return super.getString(key, options);
  }

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    if (failWrites) throw StateError('Storage full');
    return super.setString(key, value, options);
  }
}

void main() {
  const source = 'https://api.example.test/v1';
  const key = 'cat_tinder.feed.v1::$source';
  late FailingPreferences backend;

  setUp(() {
    final original = SharedPreferencesAsyncPlatform.instance;
    backend = FailingPreferences();
    SharedPreferencesAsyncPlatform.instance = backend;
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = original);
  });

  test('empty storage starts with zero likes and no card', () async {
    final snapshot = await PreferencesFeedStore(source: source).read();
    expect(snapshot.likes, 0);
    expect(snapshot.cat, isNull);
  });

  test(
    'a new store instance restores the full snapshot from one JSON entry',
    () async {
      final cat = Cat.fromJson(catJson('saved'));
      await PreferencesFeedStore(source: source)
          .write(FeedSnapshot(likes: 4, cat: cat));
      final restored = await PreferencesFeedStore(source: source).read();
      expect(restored.likes, 4);
      expect(restored.cat?.toJson(), cat.toJson());
      final entries = await SharedPreferencesAsync().getAll();
      expect(entries.keys, [key]);
      final saved = jsonDecode(entries[key] as String) as Map<String, dynamic>;
      expect(saved.keys, unorderedEquals(['version', 'likes', 'cat']));
    },
  );

  test('an accepted vote clears the old cat in the same saved entry', () async {
    final store = PreferencesFeedStore(source: source);
    await store.write(
      FeedSnapshot(likes: 4, cat: Cat.fromJson(catJson('old'))),
    );
    await store.write(const FeedSnapshot(likes: 5));
    final restored = await PreferencesFeedStore(source: source).read();
    expect(restored.likes, 5);
    expect(restored.cat, isNull);
  });

  test('different API sources do not restore each others cards', () async {
    await PreferencesFeedStore(source: source)
        .write(const FeedSnapshot(likes: 8));
    final other = await PreferencesFeedStore(
      source: 'https://other.example.test/v1',
    ).read();
    expect(other.likes, 0);
  });

  final corruptValues = [
    '{broken',
    '[]',
    jsonEncode({'version': 2, 'likes': 4, 'cat': null}),
    jsonEncode({'version': 1, 'likes': -1, 'cat': null}),
    jsonEncode({'version': 1, 'likes': '4', 'cat': null}),
    jsonEncode({
      'version': 1,
      'likes': 4,
      'cat': {...catJson('bad'), 'breeds': []},
    }),
  ];
  for (var i = 0; i < corruptValues.length; i++) {
    test('corrupt snapshot $i is reported without being overwritten', () async {
      final raw = corruptValues[i];
      await SharedPreferencesAsync().setString(key, raw);
      await expectLater(
        PreferencesFeedStore(source: source).read(),
        throwsA(
          isA<FeedStorageException>().having(
            (e) => e.canReset,
            'canReset',
            isTrue,
          ),
        ),
      );
      expect(await SharedPreferencesAsync().getString(key), raw);
    });
  }

  test(
    'read and write failures preserve the previous stored snapshot',
    () async {
      final store = PreferencesFeedStore(source: source);
      await store.write(const FeedSnapshot(likes: 6));
      backend.failReads = true;
      await expectLater(store.read(), throwsA(isA<FeedStorageException>()));
      backend.failReads = false;
      backend.failWrites = true;
      await expectLater(
        store.write(const FeedSnapshot(likes: 7)),
        throwsA(isA<FeedStorageException>()),
      );
      expect((await store.read()).likes, 6);
    },
  );
}
