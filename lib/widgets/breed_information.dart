import 'package:flutter/material.dart';

import '../models/breed.dart';

class BreedInformation extends StatelessWidget {
  const BreedInformation({super.key, required this.breed});

  final Breed breed;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(breed.name, style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 24),
      _section(context, 'О породе', [Text(breed.description ?? 'Нет данных')]),
      _section(context, 'Основные сведения', [
        _fact(context, 'Происхождение', breed.origin),
        _fact(context, 'Темперамент', breed.temperament),
        _fact(
          context,
          'Продолжительность жизни',
          breed.lifeSpan == null ? null : '${breed.lifeSpan} лет',
        ),
        _fact(context, 'Группа породы', breed.group),
        _fact(
          context,
          'Вес',
          breed.metricWeight == null ? null : '${breed.metricWeight} кг',
        ),
        if (breed.imperialWeight case final weight?)
          _fact(context, 'Вес в фунтах', weight),
        if (breed.alternativeNames case final names?)
          _fact(context, 'Другие названия', names),
        if (breed.bredFor case final purpose?)
          _fact(context, 'Для чего выведена', purpose),
        if (breed.perfectFor case final owners?)
          _fact(context, 'Кому подходит', owners),
      ]),
      if (breed.history case final history?)
        _section(context, 'История', [Text(history)]),
      if (breed.ratings.isNotEmpty)
        _section(context, 'Характеристики', [
          const Text('Оценки по данным API; максимальное значение — 5.'),
          const SizedBox(height: 16),
          for (final entry in breed.ratings.entries)
            _score(context, entry.key.label, '${entry.value} / 5'),
        ]),
      if (breed.flags.isNotEmpty)
        _section(context, 'Особенности', [
          for (final entry in breed.flags.entries)
            _score(context, entry.key.label, entry.value ? 'Да' : 'Нет'),
        ]),
      if (breed.sources.isNotEmpty)
        _section(context, 'Источники', [
          for (final entry in breed.sources.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SelectableText('${entry.key.label}\n${entry.value}'),
            ),
        ]),
    ],
  );

  Widget _section(BuildContext context, String title, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                ...children,
              ],
            ),
          ),
        ),
      );

  Widget _fact(BuildContext context, String label, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 4),
        Text(value ?? 'Нет данных'),
      ],
    ),
  );

  Widget _score(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 16),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    ),
  );
}
