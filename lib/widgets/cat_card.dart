import 'package:flutter/material.dart';

import '../models/cat.dart';

class CatCard extends StatelessWidget {
  const CatCard({
    super.key,
    required this.cat,
    required this.photo,
    required this.onDetails,
  });

  final Cat cat;
  final ImageProvider photo;
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
                  aspectRatio: 1.15,
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
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
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
                        Text(
                          temperament,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: onDetails,
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('О породе'),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
