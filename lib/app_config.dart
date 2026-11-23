class AppConfig {
  const AppConfig({
    this.apiKey = const String.fromEnvironment('CAT_API_KEY'),
    this.baseUrl = const String.fromEnvironment(
      'CAT_API_BASE_URL',
      defaultValue: 'https://api.thecatapi.com/v1',
    ),
  });

  final String apiKey;
  final String baseUrl;

  String? get validationError {
    if (apiKey.trim().isEmpty ||
        apiKey.trim() == 'PASTE_YOUR_CAT_API_KEY_HERE') {
      return 'Добавьте ключ TheCatAPI в config.json и полностью перезапустите '
          'приложение с аргументом --dart-define-from-file=config.json.';
    }
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return 'Проверьте CAT_API_BASE_URL: нужен HTTPS-адрес API '
          'без параметров запроса и фрагмента.';
    }
    return null;
  }

  Uri endpoint(String path, Map<String, String> query) {
    final root = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$root/$path').replace(queryParameters: query);
  }
}
