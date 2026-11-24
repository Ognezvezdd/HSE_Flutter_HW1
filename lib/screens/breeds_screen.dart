import 'package:flutter/material.dart';

import '../models/breed.dart';
import '../services/cat_api.dart';
import '../widgets/status_panel.dart';
import 'breed_details_screen.dart';

class BreedsScreen extends StatefulWidget {
  const BreedsScreen({super.key, required this.api, required this.isActive});

  final CatApi api;
  final bool isActive;

  @override
  State<BreedsScreen> createState() => _BreedsScreenState();
}

class _BreedsScreenState extends State<BreedsScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Breed>? _breeds;
  CatApiException? _error;
  bool _started = false;
  bool _loading = false;
  bool _openingDetails = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _load();
  }

  @override
  void didUpdateWidget(covariant BreedsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_started) _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    _started = true;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final breeds = await widget.api.fetchBreeds(refresh: refresh);
      if (!mounted) return;
      setState(() {
        _breeds = breeds;
        _loading = false;
      });
    } on CatApiException catch (error) {
      _showError(error);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'cat_tinder',
          context: ErrorDescription('while loading the breed catalog'),
        ),
      );
      _showError(
        const CatApiException(
          'Не удалось показать породы. Попробуйте ещё раз.',
        ),
      );
    }
  }

  void _showError(CatApiException error) {
    if (!mounted) return;
    setState(() {
      _error = error;
      _loading = false;
    });
  }

  Future<void> _openDetails(Breed breed) async {
    if (_openingDetails) return;
    _openingDetails = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) => BreedDetailsScreen(breed: breed),
        ),
      );
    } finally {
      _openingDetails = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final breeds = _breeds;
    final Widget content;
    if (_loading || !_started) {
      content = const StatusPanel(
        title: 'Загружаем породы',
        message: 'Собираем каталог и сведения о породах.',
        isLoading: true,
      );
    } else if (error != null) {
      content = StatusPanel(
        title: error.kind == CatApiErrorKind.authentication
            ? 'Ключ API не принят'
            : 'Каталог пока недоступен',
        message: error.message,
        icon: error.kind == CatApiErrorKind.authentication
            ? Icons.key_rounded
            : Icons.cloud_off_rounded,
        onRetry: error.canRetry ? () => _load(refresh: true) : null,
      );
    } else if (breeds == null || breeds.isEmpty) {
      content = StatusPanel(
        title: 'Пород пока нет',
        icon: Icons.pets_outlined,
        message:
            'Сервис вернул пустой список. Попробуйте загрузить его ещё раз.',
        onRetry: () => _load(refresh: true),
      );
    } else {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView.separated(
            key: const PageStorageKey('breeds_list'),
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: breeds.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Каталог пород',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Пород в каталоге: ${breeds.length}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }
              final breed = breeds[index - 1];
              return Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  key: ValueKey('breed_${breed.id}'),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.pets_outlined, size: 21),
                  ),
                  title: Text(
                    breed.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(breed.origin ?? 'Происхождение: нет данных'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDetails(breed),
                ),
              );
            },
          ),
        ),
      );
    }
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: content,
          ),
        ),
      ),
    );
  }
}
