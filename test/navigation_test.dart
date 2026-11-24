import 'dart:async';
import 'dart:convert';

import 'package:cat_tinder/app_config.dart';
import 'package:cat_tinder/app_theme.dart';
import 'package:cat_tinder/models/cat.dart';
import 'package:cat_tinder/models/feed_snapshot.dart';
import 'package:cat_tinder/screens/breed_details_screen.dart';
import 'package:cat_tinder/screens/breeds_screen.dart';
import 'package:cat_tinder/screens/home_screen.dart';
import 'package:cat_tinder/services/cat_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures.dart';
import 'test_helpers.dart';

void main() {
  http.Response catalog({int count = 2}) => http.Response(
    jsonEncode(
      count == 2
          ? [breedJson('abys', 'Abyssinian'), breedJson('beng', 'Bengal')]
          : List.generate(
              count,
              (i) => breedJson('b$i', 'Breed ${i.toString().padLeft(2, '0')}'),
            ),
    ),
    200,
  );

  CatApi apiFor(Future<http.Response> Function(http.Request) handler) {
    final api = CatApi(
      client: MockClient(handler),
      config: const AppConfig(apiKey: 'test-only-key'),
    );
    addTearDown(api.close);
    return api;
  }

  Future<void> mount(
    WidgetTester tester,
    CatApi api, {
    MemoryFeedStore? store,
  }) async {
    tester.view.physicalSize = const Size(390, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: createAppTheme(),
        home: HomeScreen(
          api: api,
          store: store ?? MemoryFeedStore(),
          photoProvider: (_) => MemoryImage(photoBytes),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets(
    'cat details show the same photo and Back preserves cat and likes',
    (tester) async {
      var searches = 0;
      var catalogs = 0;
      final api = apiFor((request) async {
        if (request.url.path.endsWith('/breeds')) {
          catalogs++;
          return catalog();
        }
        searches++;
        return catResponse('same-cat');
      });
      final store = MemoryFeedStore(
        initial: FeedSnapshot(likes: 3, cat: Cat.fromJson(catJson('same-cat'))),
      );
      await mount(tester, api, store: store);
      final image = tester.widget<Image>(find.byType(Image)).image;
      final writes = store.writes;
      await tester.tap(find.byKey(const Key('cat_details_button')));
      await settle(tester);
      expect(find.byType(BreedDetailsScreen), findsOneWidget);
      expect(
        tester.widget<Image>(find.byKey(const Key('cat_detail_image'))).image,
        same(image),
      );
      expect(find.text('12 - 15 лет'), findsOneWidget);
      await tester.tap(find.byKey(const Key('details_back_button')));
      await settle(tester);
      expect(
        tester.widget<Text>(find.byKey(const Key('like_counter'))).data,
        '♥ 3',
      );
      expect((await store.read()).cat?.id, 'same-cat');
      expect(store.writes, writes);
      expect(searches, 0);
      expect(catalogs, 1);
    },
  );

  testWidgets('catalog details, tab switches and Back preserve loaded data', (
    tester,
  ) async {
    var catalogs = 0;
    var searches = 0;
    final api = apiFor((request) async {
      if (request.url.path.endsWith('/breeds')) {
        catalogs++;
        return catalog();
      }
      return catResponse('cat-${++searches}');
    });
    await mount(tester, api);
    await tester.tap(find.byKey(const Key('breeds_tab')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('breed_beng')));
    await settle(tester);
    expect(
      tester
          .widget<BreedDetailsScreen>(find.byType(BreedDetailsScreen))
          .breed
          .id,
      'beng',
    );
    expect(find.byKey(const Key('cat_detail_image')), findsNothing);
    expect(find.text('Темперамент'), findsOneWidget);
    await tester.tap(find.byKey(const Key('details_back_button')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('cats_tab')));
    await settle(tester);
    expect(find.byKey(const Key('cat_card')), findsOneWidget);
    await tester.tap(find.byKey(const Key('breeds_tab')));
    await settle(tester);
    expect(find.byKey(const ValueKey('breed_beng')), findsOneWidget);
    expect(catalogs, 1);
    expect(searches, 1);
  });

  testWidgets(
    'empty catalog has a retry and recovers without changing the cat',
    (tester) async {
      var catalogs = 0;
      var searches = 0;
      final api = apiFor((request) async {
        if (request.url.path.endsWith('/breeds')) {
          return ++catalogs == 1 ? http.Response('[]', 200) : catalog();
        }
        return catResponse('cat-${++searches}');
      });
      await mount(tester, api);
      await tester.tap(find.byKey(const Key('breeds_tab')));
      await settle(tester);
      expect(find.text('Пород пока нет'), findsOneWidget);
      await tester.tap(find.byKey(const Key('retry_button')));
      await settle(tester);
      expect(find.byKey(const ValueKey('breed_beng')), findsOneWidget);
      expect(catalogs, 2);
      expect(searches, 1);
    },
  );

  testWidgets('catalog scroll position survives details and tab switching', (
    tester,
  ) async {
    final api = apiFor(
      (request) async => request.url.path.endsWith('/breeds')
          ? catalog(count: 40)
          : catResponse('one'),
    );
    await mount(tester, api);
    await tester.tap(find.byKey(const Key('breeds_tab')));
    await settle(tester);
    final list = find.byKey(const PageStorageKey('breeds_list'));
    await tester.drag(list, const Offset(0, -700));
    await settle(tester);
    double offset() => tester
        .state<ScrollableState>(
          find.descendant(of: list, matching: find.byType(Scrollable)).first,
        )
        .position
        .pixels;
    final before = offset();
    expect(before, greaterThan(0));
    await tester.tap(find.byType(ListTile).hitTestable().first);
    await settle(tester);
    await tester.tap(find.byKey(const Key('details_back_button')));
    await settle(tester);
    expect(offset(), closeTo(before, 0.1));
    await tester.tap(find.byKey(const Key('cats_tab')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('breeds_tab')));
    await settle(tester);
    expect(offset(), closeTo(before, 0.1));
  });

  testWidgets(
    'switching tabs during a request keeps one load and saved likes',
    (tester) async {
      final pending = Completer<http.Response>();
      var catalogs = 0;
      var searches = 0;
      final api = apiFor((request) async {
        if (request.url.path.endsWith('/breeds')) {
          catalogs++;
          return pending.future;
        }
        searches++;
        return catResponse('unexpected');
      });
      final saved = FeedSnapshot(likes: 7, cat: Cat.fromJson(catJson('saved')));
      final store = MemoryFeedStore(initial: saved);
      tester.view.physicalSize = const Size(390, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            api: api,
            store: store,
            photoProvider: (_) => MemoryImage(photoBytes),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('breeds_tab')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('cats_tab')));
      await tester.pump(const Duration(milliseconds: 300));
      pending.complete(catalog());
      await settle(tester);
      expect(find.byKey(const Key('cat_card')), findsOneWidget);
      expect((await store.read()).likes, 7);
      expect((await store.read()).cat?.id, 'saved');
      await tester.tap(find.byKey(const Key('breeds_tab')));
      await settle(tester);
      expect(find.byKey(const ValueKey('breed_beng')), findsOneWidget);
      expect(catalogs, 1);
      expect(searches, 0);
    },
  );

  testWidgets(
    'cat request failure keeps the loaded catalog and accepted like',
    (tester) async {
      final api = apiFor(
        (request) async => request.url.path.endsWith('/breeds')
            ? catalog()
            : http.Response('', 500),
      );
      final store = MemoryFeedStore(
        initial: FeedSnapshot(likes: 2, cat: Cat.fromJson(catJson('saved'))),
      );
      await mount(tester, api, store: store);
      await tester.tap(find.byKey(const Key('like_button')));
      await settle(tester);
      expect(find.byKey(const Key('retry_button')), findsOneWidget);
      expect((await store.read()).likes, 3);
      await tester.tap(find.byKey(const Key('breeds_tab')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('breed_beng')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('details_back_button')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('cats_tab')));
      await settle(tester);
      expect(find.byKey(const Key('retry_button')), findsOneWidget);
      expect((await store.read()).likes, 3);
    },
  );

  testWidgets(
    'catalog errors can be retried and disposal during request is safe',
    (tester) async {
      var requests = 0;
      final api = apiFor(
        (_) async => ++requests == 1 ? http.Response('', 500) : catalog(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BreedsScreen(api: api, isActive: true)),
        ),
      );
      await settle(tester);
      expect(find.text('Каталог пока недоступен'), findsOneWidget);
      await tester.tap(find.byKey(const Key('retry_button')));
      await settle(tester);
      expect(find.byKey(const ValueKey('breed_abys')), findsOneWidget);
      final pending = Completer<http.Response>();
      final pendingApi = apiFor((_) => pending.future);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreedsScreen(
              key: const Key('pending'),
              api: pendingApi,
              isActive: true,
            ),
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      pending.complete(catalog());
      await settle(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('details fit narrow screens and enlarged text', (tester) async {
    final api = apiFor(
      (request) async =>
          request.url.path.endsWith('/breeds') ? catalog() : catResponse('one'),
    );
    await mount(tester, api);
    await tester.tap(find.byKey(const Key('cat_details_button')));
    await settle(tester);
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await settle(tester);
    await tester.drag(
      find.byKey(const Key('breed_details_scroll')),
      const Offset(0, -1200),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
