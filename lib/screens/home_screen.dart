import 'dart:async';

import 'package:flutter/material.dart';

import '../models/cat.dart';
import '../models/feed_snapshot.dart';
import '../services/cat_api.dart';
import '../services/feed_store.dart';
import '../widgets/cat_card.dart';
import '../widgets/cat_actions.dart';
import '../widgets/status_panel.dart';
import 'breed_details_screen.dart';
import 'breeds_screen.dart';

enum _FeedPhase { loading, ready, error }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.api,
    required this.store,
    this.photoProvider = _networkPhoto,
  });

  final CatApi api;
  final FeedStore store;
  final ImageProvider Function(Uri) photoProvider;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _FeedPhase _phase = _FeedPhase.loading;
  FeedSnapshot _snapshot = const FeedSnapshot();
  ImageProvider? _photo;
  Object? _error;
  VoidCallback? _retryAction;
  int _cardNumber = 0;
  bool _requestInFlight = false;
  bool _restored = false;
  bool _resetDialogOpen = false;
  bool _detailsOpen = false;
  bool _swipeInProgress = false;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() => _run(() async {
    _retryAction = _restore;
    final saved = await widget.store.read();
    if (!mounted) return;
    setState(() {
      _snapshot = saved;
      _restored = true;
    });
    _retryAction = () => _loadCat();
    await _prepareCat(saved.cat);
  });

  Future<void> _loadCat({Cat? candidate}) => _run(() async {
    _retryAction = () => _loadCat(candidate: candidate);
    await _prepareCat(candidate ?? _snapshot.cat);
  });

  Future<void> _prepareCat(Cat? candidate) async {
    await widget.api.ensureAccess();
    if (!mounted) return;
    final loaded = candidate ?? await widget.api.fetchRandomCat();
    final cat = loaded.breed.id == null
        ? widget.api.completeCat(loaded)
        : loaded;
    if (!mounted) return;
    _retryAction = () => _loadCat(candidate: cat);
    if (!identical(_snapshot.cat, cat)) {
      await _persist(FeedSnapshot(likes: _snapshot.likes, cat: cat));
      if (!mounted) return;
    }
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
      _swipeInProgress = false;
      _cardNumber++;
    });
  }

  Future<void> _persist(FeedSnapshot next) async {
    await widget.store.write(next);
    if (!mounted) return;
    setState(() {
      _snapshot = next;
      _restored = true;
    });
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_requestInFlight) return;
    _requestInFlight = true;
    setState(() {
      _phase = _FeedPhase.loading;
      _error = null;
      _photo = null;
    });
    try {
      await operation();
    } on CatApiException catch (error) {
      _showError(error);
    } on FeedStorageException catch (error) {
      _showError(error);
    } on TimeoutException {
      _showError(
        const CatApiException(
          'Фотография загружается слишком долго. Попробуйте ещё раз.',
        ),
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'cat_tinder',
          context: ErrorDescription('while restoring or updating the cat feed'),
        ),
      );
      _showError(
        const CatApiException('Не удалось показать кота. Попробуйте ещё раз.'),
      );
    } finally {
      _requestInFlight = false;
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    setState(() {
      _phase = _FeedPhase.error;
      _error = error;
    });
  }

  void _vote(Cat cat, {required bool liked}) {
    if (_detailsOpen ||
        _phase != _FeedPhase.ready ||
        !identical(_snapshot.cat, cat)) {
      return;
    }
    _commitVote(FeedSnapshot(likes: _snapshot.likes + (liked ? 1 : 0)));
  }

  Future<void> _openDetails(Cat cat, ImageProvider photo) async {
    if (_detailsOpen ||
        _swipeInProgress ||
        _phase != _FeedPhase.ready ||
        !identical(_snapshot.cat, cat)) {
      return;
    }
    _detailsOpen = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) =>
              BreedDetailsScreen(breed: cat.breed, photo: photo),
        ),
      );
    } finally {
      _detailsOpen = false;
    }
  }

  Future<void> _commitVote(FeedSnapshot next) => _run(() async {
    _retryAction = () => _commitVote(next);
    await _persist(next);
    if (!mounted) return;
    _retryAction = () => _loadCat();
    await _prepareCat(null);
  });

  Future<void> _confirmReset() async {
    if (_requestInFlight || _resetDialogOpen) return;
    _resetDialogOpen = true;
    final bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Начать заново?'),
          content: const Text('Сохранённые лайки и текущий кот будут удалены.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Сбросить'),
            ),
          ],
        ),
      );
    } finally {
      _resetDialogOpen = false;
    }
    if (confirmed == true && mounted) await _reset();
  }

  Future<void> _reset() => _run(() async {
    _retryAction = _reset;
    await _persist(const FeedSnapshot());
    if (!mounted) return;
    _retryAction = () => _loadCat();
    await _prepareCat(null);
  });

  @override
  Widget build(BuildContext context) {
    final configurationError = widget.api.config.validationError;
    final cat = _snapshot.cat;
    final photo = _photo;
    final Widget content;
    if (configurationError != null) {
      content = StatusPanel(
        title: 'Подключим котов',
        icon: Icons.key_rounded,
        message: configurationError,
      );
    } else if (_phase == _FeedPhase.error) {
      final error = _error;
      if (error is FeedStorageException) {
        content = StatusPanel(
          title: 'Локальные данные недоступны',
          icon: Icons.save_outlined,
          message: error.message,
          onRetry: _retryAction,
          onReset: error.canReset ? _confirmReset : null,
        );
      } else {
        final failure = error is CatApiException
            ? error
            : const CatApiException('Попробуйте ещё раз.');
        content = StatusPanel(
          title: failure.kind == CatApiErrorKind.authentication
              ? 'Ключ API не принят'
              : cat == null
              ? 'Кот пока не нашёлся'
              : 'Не удалось загрузить кота',
          icon: failure.kind == CatApiErrorKind.authentication
              ? Icons.key_rounded
              : Icons.cloud_off_rounded,
          message: failure.message,
          onRetry: failure.canRetry ? _retryAction : null,
        );
      }
    } else if (_phase == _FeedPhase.ready && cat != null && photo != null) {
      content = Dismissible(
        key: ValueKey(_cardNumber),
        direction: DismissDirection.horizontal,
        background: _swipeBackground(context, liked: true),
        secondaryBackground: _swipeBackground(context, liked: false),
        onUpdate: (details) {
          if (_phase == _FeedPhase.ready && identical(_snapshot.cat, cat)) {
            _swipeInProgress = details.progress > 0;
          }
        },
        onDismissed: (direction) =>
            _vote(cat, liked: direction == DismissDirection.startToEnd),
        child: CatCard(
          cat: cat,
          photo: photo,
          onDetails: () => _openDetails(cat, photo),
        ),
      );
    } else {
      content = const StatusPanel(
        title: 'Ищем вашего следующего кота',
        message: 'Загружаем фотографию и сведения о породе.',
        isLoading: true,
      );
    }

    final feed = SafeArea(
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                key: const Key('cat_feed_scroll'),
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 32).clamp(
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
              ),
            ),
          ),
          if (configurationError == null &&
              _phase == _FeedPhase.ready &&
              cat != null &&
              photo != null)
            CatActions(
              onLike: () => _vote(cat, liked: true),
              onSkip: () => _vote(cat, liked: false),
            ),
        ],
      ),
    );
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  image: const DecorationImage(
                    image: AssetImage('assets/branding/app_icon.png'),
                  ),
                ),
                child: const SizedBox.square(dimension: 32),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Кототиндер',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Semantics(
                identifier: 'like_counter',
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    _restored ? '♥ ${_snapshot.likes}' : '♥ —',
                    key: const Key('like_counter'),
                    semanticsLabel: _restored
                        ? 'Лайков: ${_snapshot.likes}'
                        : 'Загрузка лайков',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            ),
          ],
          bottom: TabBar(
            onTap: (index) => setState(() => _selectedTab = index),
            tabs: [
              const Tab(key: Key('cats_tab'), height: 48, child: Text('Коты')),
              Semantics(
                identifier: 'breeds_tab',
                child: const Tab(
                  key: Key('breeds_tab'),
                  height: 48,
                  child: Text('Породы'),
                ),
              ),
            ],
          ),
        ),
        body: IndexedStack(
          index: _selectedTab,
          children: [
            TickerMode(enabled: _selectedTab == 0, child: feed),
            TickerMode(
              enabled: _selectedTab == 1,
              child: SafeArea(
                child: BreedsScreen(
                  api: widget.api,
                  isActive: _selectedTab == 1,
                ),
              ),
            ),
          ],
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
