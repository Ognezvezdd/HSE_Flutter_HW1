import 'package:flutter/material.dart';

class StatusPanel extends StatelessWidget {
  const StatusPanel({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.onReset,
    this.isLoading = false,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onReset;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          const CircularProgressIndicator()
        else
          Icon(
            Icons.pets_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: 24),
          Semantics(
            identifier: 'retry_button',
            child: FilledButton.icon(
              key: const Key('retry_button'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ),
        ],
        if (onReset != null) ...[
          const SizedBox(height: 12),
          TextButton(onPressed: onReset, child: const Text('Начать заново')),
        ],
      ],
    ),
  );
}
