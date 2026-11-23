import 'dart:async';
import 'dart:convert';

import 'package:cat_tinder/app_config.dart';
import 'package:cat_tinder/services/cat_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures.dart';

void main() {
  const config = AppConfig(
    apiKey: 'test-only-key',
    baseUrl: 'https://api.example.test/custom/v1/',
  );

  CatApi apiFor(
    Future<http.Response> Function(http.Request) handler, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    final api = CatApi(
      client: MockClient(handler),
      config: config,
      timeout: timeout,
    );
    addTearDown(api.close);
    return api;
  }

  test(
    'uses configured API path and binds breed to the returned cat',
    () async {
      final api = apiFor((request) async {
        expect(request.url.path, '/custom/v1/images/search');
        expect(request.url.queryParameters['has_breeds'], '1');
        expect(request.headers['x-api-key'], 'test-only-key');
        return catResponse('one');
      });
      final cat = await api.fetchRandomCat();
      expect(cat.id, 'one');
      expect(cat.imageUrl.toString(), 'https://images.example.test/one.png');
      expect(cat.breed.name, 'Abyssinian');
    },
  );

  for (final key in ['', 'PASTE_YOUR_CAT_API_KEY_HERE']) {
    test(
      'does not send a request with missing or placeholder key: $key',
      () async {
        var requests = 0;
        final api = CatApi(
          client: MockClient((_) async {
            requests++;
            return catResponse('one');
          }),
          config: AppConfig(apiKey: key),
        );
        addTearDown(api.close);
        await expectLater(
          api.fetchRandomCat(),
          throwsA(isA<CatApiException>()),
        );
        expect(requests, 0);
      },
    );
  }

  test('rejects insecure or malformed base URLs', () {
    for (final url in [
      'http://example.test/v1',
      'not a URL',
      'https://example.test/v1?key=value',
      'https://user:password@example.test/v1',
    ]) {
      expect(
        AppConfig(apiKey: 'test', baseUrl: url).validationError,
        isNotNull,
      );
    }
  });

  for (final code in [401, 403, 429, 500]) {
    test('handles HTTP $code without exposing the response body', () async {
      final api = apiFor((_) async => http.Response('private response', code));
      await expectLater(
        api.fetchRandomCat(),
        throwsA(
          isA<CatApiException>().having(
            (e) => e.message,
            'message',
            isNot(contains('private response')),
          ),
        ),
      );
    });
  }

  final invalidResponses = <String, String>{
    'empty list': '[]',
    'invalid JSON': '<html>error</html>',
    'wrong root type': '{}',
    'no breed': jsonEncode([
      {...catJson('one'), 'breeds': []},
    ]),
    'wrong field type': jsonEncode([
      {...catJson('one'), 'id': 42},
    ]),
    'insecure image': jsonEncode([
      {...catJson('one'), 'url': 'http://example.test/a.png'},
    ]),
  };
  for (final entry in invalidResponses.entries) {
    test('handles ${entry.key}', () async {
      final api = apiFor((_) async => http.Response(entry.value, 200));
      await expectLater(api.fetchRandomCat(), throwsA(isA<CatApiException>()));
    });
  }

  test('handles network failures', () async {
    final api = apiFor(
      (_) async => throw http.ClientException('internal detail'),
    );
    await expectLater(api.fetchRandomCat(), throwsA(isA<CatApiException>()));
  });

  test('times out a request that never completes', () async {
    final pending = Completer<http.Response>();
    final api = apiFor(
      (_) => pending.future,
      timeout: const Duration(milliseconds: 5),
    );
    await expectLater(
      api.fetchRandomCat(),
      throwsA(
        isA<CatApiException>().having(
          (e) => e.message,
          'message',
          contains('долго'),
        ),
      ),
    );
    pending.complete(catResponse('late'));
  });
}
