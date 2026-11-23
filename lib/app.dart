import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'screens/home_screen.dart';
import 'services/cat_api.dart';
import 'services/feed_store.dart';

class CatTinderApp extends StatefulWidget {
  const CatTinderApp({
    super.key,
    this.config = const AppConfig(),
    this.feedStore,
  });

  final AppConfig config;
  final FeedStore? feedStore;

  @override
  State<CatTinderApp> createState() => _CatTinderAppState();
}

class _CatTinderAppState extends State<CatTinderApp> {
  late final CatApi _api = CatApi(client: http.Client(), config: widget.config);
  late final FeedStore _store =
      widget.feedStore ?? PreferencesFeedStore(source: widget.config.baseUrl);

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Кототиндер',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF167569),
        surface: const Color(0xFFFAF8F4),
      ),
      scaffoldBackgroundColor: const Color(0xFFFAF8F4),
      useMaterial3: true,
    ),
    home: HomeScreen(api: _api, store: _store),
  );
}
