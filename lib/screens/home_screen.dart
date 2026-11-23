import 'dart:async';

import 'package:flutter/material.dart';

import '../models/cat.dart';
import '../services/cat_api.dart';
import '../widgets/cat_card.dart';
import '../widgets/status_panel.dart';

enum _FeedPhase { loading, ready, error }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.api,
    this.photoProvider = _networkPhoto,
  });

  final CatApi api;
  final ImageProvider Function(Uri) photoProvider;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _FeedPhase _phase = _FeedPhase.loading;
  Cat? _cat;
  ImageProvider? _photo;
  String? _error;
  int _likes = 0;
  int _cardNumber = 0;
  bool _requestInFlight = false;

  @override
  void initState() {
    super.initState();
    _loadCat();
  }

  Future<void> _loadCat({bool retryPhoto = false}) async {
    if (_requestInFlight) return;
    _requestInFlight = true;
    setState(() {
      _phase = _FeedPhase.loading;
      _error = null;
      _photo = null;
      if (!retryPhoto) _cat = null;
    });
    try {
      final cat = _cat ?? await widget.api.fetchRandomCat();
      if (!mounted) return;
      _cat = cat;
      final photo = widget.photoProvider(cat.imageUrl);
      var decodingFailed = false;
      await precacheImage(
        photo,
        context,
        onError: (error, stackTrace) {
          decodingFailed = true;
        },
      ).timeout(widget.api.timeout);
      if (!mounted) return;
      if (decodingFailed) {
        throw const CatApiException(
          'Не удалось открыть фотографию. Попробуйте загрузить её ещё раз.',
        );
      }
      setState(() {
        _photo = photo;
        _phase = _FeedPhase.ready;
        _cardNumber++;
      });
    } on CatApiException catch (error) {
      _showError(error.message);
    } on TimeoutException {
      _showError('Фотография загружается слишком долго. Попробуйте ещё раз.');
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'cat_tinder',
          context: ErrorDescription('while loading a cat card'),
        ),
      );
      _showError('Не удалось показать кота. Попробуйте ещё раз.');
    } finally {
      _requestInFlight = false;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _FeedPhase.error;
      _error = message;
    });
  }

  void _vote(Cat cat, {required bool liked}) {
    if (_phase != _FeedPhase.ready || !identical(_cat, cat)) return;
    if (liked) _likes++;
    _loadCat();
  }

  @override
  Widget build(BuildContext context) {
    final configurationError = widget.api.config.validationError;
    final cat = _cat;
    final photo = _photo;
    final Widget content;
    if (configurationError != null) {
      content = StatusPanel(
        title: 'Подключим котов',
        message: configurationError,
      );
    } else if (_phase == _FeedPhase.error) {
      content = StatusPanel(
        title: _cat == null
            ? 'Кот пока не нашёлся'
            : 'Не удалось загрузить фото',
        message: _error ?? 'Попробуйте ещё раз.',
        onRetry: () => _loadCat(retryPhoto: _cat != null),
      );
    } else if (_phase == _FeedPhase.ready && cat != null && photo != null) {
      content = Dismissible(
        key: ValueKey(_cardNumber),
        direction: DismissDirection.horizontal,
        background: _swipeBackground(context, liked: true),
        secondaryBackground: _swipeBackground(context, liked: false),
        onDismissed: (direction) =>
            _vote(cat, liked: direction == DismissDirection.startToEnd),
        child: CatCard(
          cat: cat,
          photo: photo,
          onLike: () => _vote(cat, liked: true),
          onSkip: () => _vote(cat, liked: false),
        ),
      );
    } else {
      content = const StatusPanel(
        title: 'Ищем вашего следующего кота',
        message: 'Загружаем фотографию и сведения о породе.',
        isLoading: true,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Кототиндер'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Semantics(
              identifier: 'like_counter',
              liveRegion: true,
              child: Text(
                '♥ $_likes',
                key: const Key('like_counter'),
                semanticsLabel: 'Лайков: $_likes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 40).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: content,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _swipeBackground(BuildContext context, {required bool liked}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      alignment: liked ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: liked ? colors.primaryContainer : colors.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(liked ? Icons.favorite : Icons.close, size: 40),
    );
  }
}

ImageProvider _networkPhoto(Uri url) => NetworkImage(
  url.toString(),
  webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
);
