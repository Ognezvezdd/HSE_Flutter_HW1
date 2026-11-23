import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../models/cat.dart';

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
      return Cat.fromJson(first);
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
    _accessVerified = false;
    final response = await _get(
      config.endpoint('breeds', const {}),
      headers: _headers,
    );
    _requireSuccess(response);
    _accessVerified = true;
  }

  void _requireSuccess(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      _accessVerified = false;
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
