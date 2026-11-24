import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

class CatActions extends StatelessWidget {
  const CatActions({super.key, required this.onLike, required this.onSkip});

  final VoidCallback onLike;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).scaffoldBackgroundColor,
      border: Border(
        top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 330 ||
                  MediaQuery.textScalerOf(context).scale(15) > 21;
              final width = stacked
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: width,
                        child: Semantics(
                          identifier: 'dislike_button',
                          child: OutlinedButton.icon(
                            key: const Key('dislike_button'),
                            onPressed: onSkip,
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Пропустить'),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: Semantics(
                          identifier: 'like_button',
                          child: FilledButton.icon(
                            key: const Key('like_button'),
                            onPressed: onLike,
                            icon: const Icon(CupertinoIcons.heart),
                            label: const Text('Нравится'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Влево — пропустить · Вправо — лайк',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
