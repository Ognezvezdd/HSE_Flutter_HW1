import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../models/cat.dart';

class CatCard extends StatelessWidget {
  const CatCard({
    super.key,
    required this.cat,
    required this.photo,
    required this.onLike,
    required this.onSkip,
    required this.onDetails,
  });

  final Cat cat;
  final ImageProvider photo;
  final VoidCallback onLike;
  final VoidCallback onSkip;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          identifier: 'cat_card',
          child: Card(
            key: const Key('cat_card'),
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: InkWell(
                    key: const Key('cat_details_button'),
                    onTap: onDetails,
                    child: Image(
                      image: photo,
                      fit: BoxFit.cover,
                      semanticLabel:
                          'Открыть сведения о коте породы ${cat.breed.name}',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        identifier: 'cat_breed_name',
                        child: Text(
                          cat.breed.name,
                          key: const Key('cat_breed_name'),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      if (cat.breed.origin case final origin?) ...[
                        const SizedBox(height: 8),
                        Text(origin, style: TextStyle(color: colors.primary)),
                      ],
                      if (cat.breed.temperament case final temperament?) ...[
                        const SizedBox(height: 12),
                        Text(temperament),
                      ],
                      if (cat.breed.description case final description?) ...[
                        const SizedBox(height: 16),
                        Text(
                          description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Нажмите на фото, чтобы узнать больше',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Semantics(
              identifier: 'dislike_button',
              child: OutlinedButton.icon(
                key: const Key('dislike_button'),
                onPressed: onSkip,
                icon: const Icon(Icons.close),
                label: const Text('Пропустить'),
              ),
            ),
            Semantics(
              identifier: 'like_button',
              child: FilledButton.icon(
                key: const Key('like_button'),
                onPressed: onLike,
                icon: const Icon(CupertinoIcons.heart),
                label: const Text('Нравится'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Влево — пропустить · Вправо — лайк',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
