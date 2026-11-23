import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../models/cat.dart';

class CatApiException implements Exception {
  const CatApiException(this.message);

  final String message;
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

  Future<Cat> fetchRandomCat() async {
    final configurationError = config.validationError;
    if (configurationError != null) throw CatApiException(configurationError);
    final response = await _get(
      config.endpoint('images/search', {
        'has_breeds': '1',
        'limit': '1',
        'mime_types': 'jpg,png',
      }),
      headers: {
        'x-api-key': config.apiKey.trim(),
        'Accept': 'application/json',
      },
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const CatApiException(
        'TheCatAPI не принял ключ. Проверьте его в config.json '
        'и полностью перезапустите приложение.',
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
      throw const CatApiException(
        'Сервис прислал кота без породы. Попробуйте загрузить другого.',
      );
    } on FormatException {
      throw const CatApiException(
        'Не удалось прочитать данные кота. Попробуйте ещё раз.',
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
