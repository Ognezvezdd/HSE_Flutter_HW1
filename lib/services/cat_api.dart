import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../models/cat.dart';
import '../models/breed.dart';

enum CatApiErrorKind { request, configuration, authentication }

class CatApiException implements Exception {
  const CatApiException(this.message, {this.kind = CatApiErrorKind.request});

  final String message;
  final CatApiErrorKind kind;

  bool get canRetry => kind == CatApiErrorKind.request;
}

class CatApi {
  CatApi({
    required this._client,
    required this.config,
    this.timeout = const Duration(seconds: 10),
  });

  final http.Client _client;
  final AppConfig config;
  final Duration timeout;
  bool _accessVerified = false;
  List<Breed>? _cachedBreeds;
  Future<List<Breed>>? _breedsRequest;

  Map<String, String> get _headers => {
    'x-api-key': config.apiKey.trim(),
    'Accept': 'application/json',
  };

  Future<Cat> fetchRandomCat() async {
    await ensureAccess();
    final response = await _get(
      config.endpoint('images/search', {
        'has_breeds': '1',
        'limit': '1',
        'mime_types': 'jpg,png',
      }),
      headers: _headers,
    );
    _requireSuccess(response);
    return _parseCat(response);
  }

  Future<void> ensureAccess() async {
    final configurationError = config.validationError;
    if (configurationError != null) {
      throw CatApiException(
        configurationError,
        kind: CatApiErrorKind.configuration,
      );
    }
    await _verifyAccess();
  }

  Future<Cat> _parseCat(http.Response response) async {
    try {
      final Object? data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! List || data.isEmpty) {
        throw const FormatException('Empty or invalid response');
      }
      final Object? first = data.first;
      if (first is! Map<String, dynamic>) {
        throw const FormatException('Invalid cat');
      }
      return completeCat(Cat.fromJson(first));
    } on MissingBreedException {
      // Image search can silently fall back to public data with a bad key.
      await _verifyAccess(force: true);
      throw const CatApiException(
        'Сервис прислал кота без породы. Попробуйте загрузить другого.',
      );
    } on FormatException {
      throw const CatApiException(
        'Не удалось прочитать данные кота. Попробуйте ещё раз.',
      );
    }
  }

  Future<void> _verifyAccess({bool force = false}) async {
    if (_accessVerified && !force) return;
    await fetchBreeds(refresh: force);
  }

  Future<List<Breed>> fetchBreeds({bool refresh = false}) async {
    final configurationError = config.validationError;
    if (configurationError != null) {
      throw CatApiException(
        configurationError,
        kind: CatApiErrorKind.configuration,
      );
    }
    final pending = _breedsRequest;
    if (pending != null) return pending;
    final cached = _cachedBreeds;
    if (!refresh && cached != null) return cached;
    final request = _loadBreeds();
    _breedsRequest = request;
    try {
      return await request;
    } finally {
      _breedsRequest = null;
    }
  }

  Future<List<Breed>> _loadBreeds() async {
    final response = await _get(
      config.endpoint('breeds', const {'limit': '1000'}),
      headers: _headers,
    );
    _requireSuccess(response);
    final List<Breed> breeds;
    try {
      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) throw const FormatException('Invalid breed list');
      breeds = [];
      final ids = <String>{};
      for (final Object? item in decoded) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid breed');
        }
        final breed = Breed.fromJson(item);
        final id = breed.id;
        if (id == null || !ids.add(id)) {
          throw const FormatException('Missing or duplicate breed ID');
        }
        breeds.add(breed);
      }
      breeds.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    } on FormatException {
      throw const CatApiException(
        'Не удалось прочитать список пород. Попробуйте ещё раз.',
      );
    }
    _accessVerified = true;
    return _cachedBreeds = List.unmodifiable(breeds);
  }

  Cat completeCat(Cat cat) {
    final matches = _cachedBreeds
        ?.where(
          (breed) => cat.breed.id != null
              ? breed.id == cat.breed.id
              : breed.name.toLowerCase() == cat.breed.name.toLowerCase(),
        )
        .toList();
    if (matches == null || matches.length != 1) return cat;
    final full = matches.single;
    final merged = <String, dynamic>{...cat.breed.toJson()};
    for (final entry in full.toJson().entries) {
      if (entry.value != null && entry.key != 'weight') {
        merged[entry.key] = entry.value;
      }
    }
    merged['weight'] = {
      'metric': full.metricWeight ?? cat.breed.metricWeight,
      'imperial': full.imperialWeight ?? cat.breed.imperialWeight,
    };
    return Cat(
      id: cat.id,
      imageUrl: cat.imageUrl,
      breed: Breed.fromJson(merged),
    );
  }

  void _requireSuccess(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      _accessVerified = false;
      _cachedBreeds = null;
      throw const CatApiException(
        'TheCatAPI не принял ключ доступа. Укажите действительный CAT_API_KEY '
        'в config.json, затем остановите и заново запустите приложение.',
        kind: CatApiErrorKind.authentication,
      );
    }
    if (response.statusCode == 429) {
      throw const CatApiException(
        'Слишком много запросов. Подождите немного и повторите.',
      );
    }
    if (response.statusCode != 200) {
      throw const CatApiException(
        'Сервис котов временно недоступен. Попробуйте ещё раз.',
      );
    }
  }

  Future<http.Response> _get(Uri url, {Map<String, String>? headers}) async {
    final abort = Completer<void>();
    final request = http.AbortableRequest(
      'GET',
      url,
      abortTrigger: abort.future,
    );
    if (headers != null) request.headers.addAll(headers);
    try {
      return await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(
            timeout,
            onTimeout: () {
              abort.complete();
              throw TimeoutException('Request timed out');
            },
          );
    } on TimeoutException {
      throw const CatApiException(
        'Сервер отвечает слишком долго. Попробуйте ещё раз.',
      );
    } on http.ClientException {
      throw const CatApiException(
        'Не удалось подключиться. Проверьте интернет и повторите.',
      );
    }
  }

  void close() => _client.close();
}
