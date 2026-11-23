import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cat_tinder/app.dart';
import 'package:cat_tinder/app_config.dart';
import 'package:cat_tinder/screens/home_screen.dart';
import 'package:cat_tinder/services/cat_api.dart';
import 'package:cat_tinder/models/cat.dart';
import 'package:cat_tinder/models/feed_snapshot.dart';
import 'package:cat_tinder/services/feed_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures.dart';

// Image codecs run outside the fake test clock. Yield a real frame between
// pumps so decoding can finish before testing the resulting interactions.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    do {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      if (!tester.binding.hasScheduledFrame) return;
    } while (DateTime.now().isBefore(deadline));
    fail('The screen did not settle within five seconds');
  });
}

void main() {
  CatApi apiFor(Future<http.Response> Function(http.Request) handler) {
    final api = CatApi(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/breeds')) {
          return http.Response('[]', 200);
        }
        return handler(request);
      }),
      config: const AppConfig(apiKey: 'test-only-key'),
    );
    addTearDown(api.close);
    return api;
  }

  Future<void> mount(
    WidgetTester tester,
    CatApi api, {
    ImageProvider Function(Uri)? photoProvider,
    FeedStore? store,
  }) async {
    tester.view.physicalSize = const Size(390, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          api: api,
          store: store ?? MemoryFeedStore(),
          photoProvider: photoProvider ?? (_) => MemoryImage(photoBytes),
        ),
      ),
    );
    await settle(tester);
  }

  String counter(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('like_counter'))).data ?? '';

  testWidgets('missing key shows setup instructions instead of fake cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      CatTinderApp(
        config: const AppConfig(apiKey: ''),
        feedStore: MemoryFeedStore(),
      ),
    );
    await settle(tester);
    expect(find.text('Подключим котов'), findsOneWidget);
    expect(find.byKey(const Key('cat_card')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid key shows an explicit error without retry', (
    tester,
  ) async {
    final paths = <String>[];
    final api = CatApi(
      config: const AppConfig(apiKey: 'invalid-for-testing'),
      client: MockClient((request) async {
        paths.add(request.url.path);
        return http.Response('Authentication required', 403);
      }),
    );
    addTearDown(api.close);
    await mount(tester, api);
    expect(find.text('Ключ API не принят'), findsOneWidget);
    expect(find.textContaining('CAT_API_KEY'), findsOneWidget);
    expect(find.byKey(const Key('retry_button')), findsNothing);
    expect(find.byKey(const Key('cat_card')), findsNothing);
    expect(paths, ['/v1/breeds']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('genuine missing breed can be retried', (tester) async {
    var cats = 0;
    final api = apiFor(
      (_) async => ++cats == 1
          ? http.Response(
              jsonEncode([
                {...catJson('one'), 'breeds': []},
              ]),
              200,
            )
          : catResponse('two'),
    );
    await mount(tester, api);
    expect(find.textContaining('без породы'), findsOneWidget);
    await tester.tap(find.byKey(const Key('retry_button')));
    await settle(tester);
    expect(find.byKey(const Key('cat_card')), findsOneWidget);
    expect(counter(tester), '♥ 0');
  });

  testWidgets('authentication failure after a like keeps the counter', (
    tester,
  ) async {
    var cats = 0;
    final api = apiFor(
      (_) async =>
          ++cats == 1 ? catResponse('one') : http.Response('Unauthorized', 401),
    );
    await mount(tester, api);
    await tester.tap(find.byKey(const Key('like_button')));
    await settle(tester);
    expect(find.text('Ключ API не принят'), findsOneWidget);
    expect(find.byKey(const Key('retry_button')), findsNothing);
    expect(counter(tester), '♥ 1');
  });

  testWidgets(
    'double tap accepts one like; failed next request can be retried',
    (tester) async {
      var searches = 0;
      final api = apiFor((request) async {
        searches++;
        return searches == 2
            ? http.Response('', 503)
            : catResponse('$searches');
      });
      await mount(tester, api);
      expect(find.text('Abyssinian'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('like_button')),
      );
      button.onPressed?.call();
      button.onPressed?.call();
      await settle(tester);
      expect(searches, 2);
      expect(counter(tester), '♥ 1');
      final retry = tester.widget<FilledButton>(
        find.byKey(const Key('retry_button')),
      );
      retry.onPressed?.call();
      retry.onPressed?.call();
      await settle(tester);
      expect(searches, 3);
      expect(counter(tester), '♥ 1');
      expect(find.byKey(const Key('cat_card')), findsOneWidget);
    },
  );

  testWidgets('photo retry keeps the same cat and does not refetch metadata', (
    tester,
  ) async {
    var searches = 0;
    var photos = 0;
    final api = apiFor((request) async {
      searches++;
      return catResponse('one');
    });
    await mount(
      tester,
      api,
      photoProvider: (url) {
        expect(url.toString(), 'https://images.example.test/one.png');
        photos++;
        return MemoryImage(photos == 1 ? Uint8List(0) : photoBytes);
      },
    );
    expect(find.byKey(const Key('like_button')), findsNothing);
    await tester.tap(find.byKey(const Key('retry_button')));
    await settle(tester);
    expect(searches, 1);
    expect(photos, 2);
    expect(counter(tester), '♥ 0');
    expect(find.byKey(const Key('cat_card')), findsOneWidget);
  });

  testWidgets('right swipe likes, left swipe skips', (tester) async {
    var searches = 0;
    final api = apiFor((request) async => catResponse('${++searches}'));
    await mount(tester, api);
    await tester.drag(find.byType(Dismissible), const Offset(500, 0));
    await settle(tester);
    expect(counter(tester), '♥ 1');
    expect(searches, 2);
    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await settle(tester);
    expect(counter(tester), '♥ 1');
    expect(searches, 3);
  });

  testWidgets('disposing while a request is pending is safe', (tester) async {
    final response = Completer<http.Response>();
    final api = apiFor((_) => response.future);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(api: api, store: MemoryFeedStore()),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    response.complete(catResponse('late'));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card fits a narrow viewport with enlarged text and scrolls', (
    tester,
  ) async {
    final api = apiFor((request) async => catResponse('one'));
    await mount(tester, api);
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('like_button')));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'restart restores the same cat and likes without another search',
    (tester) async {
      final store = MemoryFeedStore();
      var searches = 0;
      final api = apiFor((_) async => catResponse('cat-${++searches}'));
      await mount(tester, api, store: store);
      await tester.tap(find.byKey(const Key('like_button')));
      await settle(tester);
      expect(counter(tester), '♥ 1');
      expect((await store.read()).cat?.id, 'cat-2');

      await tester.pumpWidget(const SizedBox());
      final restartedApi = apiFor((_) async {
        fail('Restoring a saved card must not fetch another cat');
      });
      await mount(tester, restartedApi, store: store);
      expect(counter(tester), '♥ 1');
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.semanticLabel, 'Кот породы Abyssinian');
      expect((await store.read()).cat?.id, 'cat-2');
      expect(searches, 2);
      expect(find.byKey(const Key('cat_card')), findsOneWidget);
    },
  );

  testWidgets(
    'restart during next request keeps the like and consumes the old cat',
    (tester) async {
      final store = MemoryFeedStore();
      final pending = Completer<http.Response>();
      var searches = 0;
      final api = apiFor((_) async {
        if (++searches == 1) return catResponse('old');
        return pending.future;
      });
      await mount(tester, api, store: store);
      tester
          .widget<FilledButton>(find.byKey(const Key('like_button')))
          .onPressed
          ?.call();
      await tester.pump();
      final saved = await store.read();
      expect(saved.likes, 1);
      expect(saved.cat, isNull);
      await tester.pumpWidget(const SizedBox());
      final restartedApi = apiFor((_) async => catResponse('new'));
      await mount(tester, restartedApi, store: store);
      expect(counter(tester), '♥ 1');
      expect((await store.read()).cat?.id, 'new');
      pending.complete(catResponse('stale-result'));
      await settle(tester);
      expect((await store.read()).cat?.id, 'new');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed vote save can be retried without adding a second like', (
    tester,
  ) async {
    final store = MemoryFeedStore();
    var searches = 0;
    final api = apiFor((_) async => catResponse('cat-${++searches}'));
    await mount(tester, api, store: store);
    store.failWrites = true;
    await tester.tap(find.byKey(const Key('like_button')));
    await settle(tester);
    expect(find.text('Локальные данные недоступны'), findsOneWidget);
    expect(counter(tester), '♥ 0');
    expect(searches, 1);
    expect((await store.read()).cat?.id, 'cat-1');
    store.failWrites = false;
    final retry = tester.widget<FilledButton>(
      find.byKey(const Key('retry_button')),
    );
    retry.onPressed?.call();
    retry.onPressed?.call();
    await settle(tester);
    expect(counter(tester), '♥ 1');
    expect(searches, 2);
    expect((await store.read()).likes, 1);
  });

  testWidgets(
    'failed candidate save retries the same cat without searching again',
    (tester) async {
      final store = MemoryFeedStore()..failWrites = true;
      var searches = 0;
      final api = apiFor((_) async => catResponse('cat-${++searches}'));
      await mount(tester, api, store: store);
      expect(find.text('Локальные данные недоступны'), findsOneWidget);
      store.failWrites = false;
      await tester.tap(find.byKey(const Key('retry_button')));
      await settle(tester);
      expect(searches, 1);
      expect((await store.read()).cat?.id, 'cat-1');
      expect(find.byKey(const Key('cat_card')), findsOneWidget);
    },
  );

  testWidgets('read failure does not overwrite saved likes', (tester) async {
    final store = MemoryFeedStore(
      initial: FeedSnapshot(likes: 7, cat: Cat.fromJson(catJson('saved'))),
    )..failReads = true;
    var searches = 0;
    final api = apiFor((_) async => catResponse('new-${++searches}'));
    await mount(tester, api, store: store);
    expect(counter(tester), '♥ —');
    expect(store.writes, 0);
    expect(searches, 0);
    store.failReads = false;
    await tester.tap(find.byKey(const Key('retry_button')));
    await settle(tester);
    expect(counter(tester), '♥ 7');
    expect(searches, 0);
    expect((await store.read()).cat?.id, 'saved');
  });

  testWidgets('resetting corrupt data requires explicit confirmation', (
    tester,
  ) async {
    final store = MemoryFeedStore()..raw = '{broken';
    final api = apiFor((_) async => catResponse('new'));
    await mount(tester, api, store: store);
    await tester.tap(find.text('Начать заново'));
    await settle(tester);
    await tester.tap(find.text('Отмена'));
    await settle(tester);
    expect(store.raw, '{broken');
    expect(store.writes, 0);
    await tester.tap(find.text('Начать заново'));
    await settle(tester);
    await tester.tap(find.text('Сбросить'));
    await settle(tester);
    expect(counter(tester), '♥ 0');
    expect((await store.read()).cat?.id, 'new');
  });
}
