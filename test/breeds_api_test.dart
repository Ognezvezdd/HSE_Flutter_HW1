import 'dart:async';
import 'dart:convert';

import 'package:cat_tinder/app_config.dart';
import 'package:cat_tinder/models/breed.dart';
import 'package:cat_tinder/models/cat.dart';
import 'package:cat_tinder/services/cat_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures.dart';

void main() {
  http.Response catalog() => http.Response(
    jsonEncode([breedJson('beng', 'Bengal'), breedJson('abys', 'Abyssinian')]),
    200,
  );

  CatApi apiFor(Future<http.Response> Function(http.Request) handler) {
    final api = CatApi(
      client: MockClient(handler),
      config: const AppConfig(
        apiKey: 'test-only-key',
        baseUrl: 'https://api.example.test/custom',
      ),
    );
    addTearDown(api.close);
    return api;
  }

  test('catalog is sorted, cached and reused after the access check', () async {
    var requests = 0;
    final api = apiFor((request) async {
      requests++;
      expect(request.url.path, '/custom/breeds');
      expect(request.headers['x-api-key'], 'test-only-key');
      return catalog();
    });
    await api.ensureAccess();
    final breeds = await api.fetchBreeds();
    expect(breeds.map((b) => b.name), ['Abyssinian', 'Bengal']);
    await api.fetchBreeds();
    expect(requests, 1);
    expect(() => breeds.clear(), throwsUnsupportedError);
  });

  test(
    'concurrent access check and catalog request share one HTTP operation',
    () async {
      final pending = Completer<http.Response>();
      var requests = 0;
      final api = apiFor((_) {
        requests++;
        return pending.future;
      });
      final access = api.ensureAccess();
      final breeds = api.fetchBreeds();
      await Future<void>.delayed(Duration.zero);
      expect(requests, 1);
      pending.complete(catalog());
      await access;
      expect(await breeds, hasLength(2));
    },
  );

  test('invalid catalog is not cached and can be retried', () async {
    var requests = 0;
    final api = apiFor(
      (_) async => ++requests == 1
          ? http.Response('[{"name":"Missing ID"}]', 200)
          : catalog(),
    );
    await expectLater(api.fetchBreeds(), throwsA(isA<CatApiException>()));
    expect(await api.fetchBreeds(), hasLength(2));
    expect(requests, 2);
  });

  test(
    'failed refresh preserves the last successfully loaded catalog',
    () async {
      var requests = 0;
      final api = apiFor(
        (_) async => ++requests == 1 ? catalog() : http.Response('', 500),
      );
      await api.fetchBreeds();
      await expectLater(
        api.fetchBreeds(refresh: true),
        throwsA(isA<CatApiException>()),
      );
      expect(await api.fetchBreeds(), hasLength(2));
      expect(requests, 2);
    },
  );

  test(
    'an empty catalog is a valid empty result, not an endless loader',
    () async {
      final api = apiFor((_) async => http.Response('[]', 200));
      expect(await api.fetchBreeds(), isEmpty);
    },
  );

  test('legacy cat is enriched without changing its image or ID', () async {
    final api = apiFor(
      (_) async => http.Response(
        jsonEncode([
          {...breedJson('abys', 'Abyssinian')}..remove('intelligence'),
        ]),
        200,
      ),
    );
    await api.ensureAccess();
    final legacy = Cat.fromJson({
      ...catJson('same-photo'),
      'breeds': [
        {'name': 'Abyssinian', 'intelligence': 5},
      ],
    });
    final complete = api.completeCat(legacy);
    expect(complete.id, legacy.id);
    expect(complete.imageUrl, legacy.imageUrl);
    expect(complete.breed.id, 'abys');
    expect(complete.breed.lifeSpan, '12 - 15');
    expect(complete.breed.ratings[BreedRating.intelligence], 5);
  });
}
