import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cat.dart';
import '../models/feed_snapshot.dart';

abstract interface class FeedStore {
  Future<FeedSnapshot> read();
  Future<void> write(FeedSnapshot snapshot);
}

class FeedStorageException implements Exception {
  const FeedStorageException(this.message, {this.canReset = false});

  final String message;
  final bool canReset;
}

class PreferencesFeedStore implements FeedStore {
  PreferencesFeedStore({required String source})
    : _key = 'cat_tinder.feed.v1::${source.replaceFirst(RegExp(r'/+$'), '')}';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final String _key;

  @override
  Future<FeedSnapshot> read() async {
    try {
      final raw = await _preferences.getString(_key);
      if (raw == null) return const FeedSnapshot();
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid saved feed');
      }
      return FeedSnapshot.fromJson(decoded);
    } on FormatException {
      throw _corruptData;
    } on MissingBreedException {
      throw _corruptData;
    } on TypeError {
      throw _corruptData;
    } catch (_) {
      throw const FeedStorageException(
        'Не удалось прочитать сохранённую ленту. Данные не сброшены. '
        'Проверьте доступ к хранилищу и повторите.',
      );
    }
  }

  @override
  Future<void> write(FeedSnapshot snapshot) async {
    try {
      await _preferences.setString(_key, jsonEncode(snapshot.toJson()));
    } catch (_) {
      throw const FeedStorageException(
        'Не удалось сохранить изменение. Оно не принято. '
        'Освободите место или проверьте доступ к хранилищу и повторите.',
      );
    }
  }

  static const _corruptData = FeedStorageException(
    'Сохранённая лента повреждена или имеет неподдерживаемый формат. '
    'Можно повторить чтение или начать заново со сбросом локальных лайков.',
    canReset: true,
  );
}
