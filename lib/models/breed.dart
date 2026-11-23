import 'json_fields.dart';

enum BreedRating {
  adaptability('adaptability', 'Адаптивность'),
  affection('affection_level', 'Ласковость'),
  childFriendly('child_friendly', 'Отношение к детям'),
  catFriendly('cat_friendly', 'Отношение к кошкам'),
  dogFriendly('dog_friendly', 'Отношение к собакам'),
  energy('energy_level', 'Энергичность'),
  grooming('grooming', 'Потребность в уходе'),
  healthIssues('health_issues', 'Предрасположенность к проблемам здоровья'),
  intelligence('intelligence', 'Интеллект'),
  shedding('shedding_level', 'Линька'),
  socialNeeds('social_needs', 'Потребность в общении'),
  strangerFriendly('stranger_friendly', 'Отношение к незнакомцам'),
  vocalisation('vocalisation', 'Разговорчивость');

  const BreedRating(this.apiKey, this.label);
  final String apiKey;
  final String label;
}

enum BreedFlag {
  indoor('indoor', 'Для содержания дома'),
  lap('lap', 'Любит сидеть на коленях'),
  experimental('experimental', 'Экспериментальная порода'),
  hairless('hairless', 'Бесшёрстная'),
  natural('natural', 'Естественного происхождения'),
  rare('rare', 'Редкая порода'),
  rex('rex', 'Кудрявая шерсть'),
  suppressedTail('suppressed_tail', 'Укороченный хвост'),
  shortLegs('short_legs', 'Короткие лапы'),
  hypoallergenic('hypoallergenic', 'Признак гипоаллергенности в API');

  const BreedFlag(this.apiKey, this.label);
  final String apiKey;
  final String label;
}

enum BreedSource {
  wikipedia('wikipedia_url', 'Wikipedia'),
  cfa('cfa_url', 'Cat Fanciers’ Association'),
  vetstreet('vetstreet_url', 'Vetstreet'),
  vca('vcahospitals_url', 'VCA');

  const BreedSource(this.apiKey, this.label);
  final String apiKey;
  final String label;
}

class Breed {
  const Breed({
    required this.name,
    this.id,
    this.origin,
    this.temperament,
    this.description,
    this.lifeSpan,
    this.group,
    this.history,
    this.alternativeNames,
    this.metricWeight,
    this.imperialWeight,
    this.bredFor,
    this.perfectFor,
    this.ratings = const {},
    this.flags = const {},
    this.sources = const {},
  });

  factory Breed.fromJson(Map<String, dynamic> json) {
    final Object? weight = json['weight'];
    if (weight != null && weight is! Map<String, dynamic>) {
      throw const FormatException('Invalid weight');
    }
    final weightFields = weight is Map<String, dynamic>
        ? weight
        : <String, dynamic>{};
    final ratings = <BreedRating, int>{};
    for (final field in BreedRating.values) {
      final Object? value = json[field.apiKey];
      if (value == null) continue;
      if (value is! num ||
          !value.isFinite ||
          value != value.roundToDouble() ||
          value < 0 ||
          value > 5) {
        throw FormatException('Invalid ${field.apiKey}');
      }
      ratings[field] = value.toInt();
    }
    final flags = <BreedFlag, bool>{};
    for (final field in BreedFlag.values) {
      final Object? value = json[field.apiKey];
      if (value == null) continue;
      if (value is bool) {
        flags[field] = value;
      } else if (value is num && (value == 0 || value == 1)) {
        flags[field] = value == 1;
      } else {
        throw FormatException('Invalid ${field.apiKey}');
      }
    }
    final sources = <BreedSource, Uri>{};
    for (final field in BreedSource.values) {
      final text = optionalText(json, field.apiKey);
      if (text == null) continue;
      final uri = Uri.tryParse(text);
      if (uri == null ||
          !['https', 'http'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw FormatException('Invalid ${field.apiKey}');
      }
      sources[field] = uri;
    }
    return Breed(
      id: optionalText(json, 'id'),
      name: requiredText(json, 'name'),
      origin: optionalText(json, 'origin'),
      temperament: optionalText(json, 'temperament'),
      description: optionalText(json, 'description'),
      lifeSpan: optionalText(json, 'life_span'),
      group: optionalText(json, 'breed_group'),
      history: optionalText(json, 'history'),
      alternativeNames: optionalText(json, 'alt_names'),
      metricWeight: optionalText(weightFields, 'metric'),
      imperialWeight: optionalText(weightFields, 'imperial'),
      bredFor: optionalText(json, 'bred_for'),
      perfectFor: optionalText(json, 'perfect_for'),
      ratings: Map.unmodifiable(ratings),
      flags: Map.unmodifiable(flags),
      sources: Map.unmodifiable(sources),
    );
  }

  final String? id;
  final String name;
  final String? origin;
  final String? temperament;
  final String? description;
  final String? lifeSpan;
  final String? group;
  final String? history;
  final String? alternativeNames;
  final String? metricWeight;
  final String? imperialWeight;
  final String? bredFor;
  final String? perfectFor;
  final Map<BreedRating, int> ratings;
  final Map<BreedFlag, bool> flags;
  final Map<BreedSource, Uri> sources;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'origin': origin,
    'temperament': temperament,
    'description': description,
    'life_span': lifeSpan,
    'breed_group': group,
    'history': history,
    'alt_names': alternativeNames,
    'weight': {'metric': metricWeight, 'imperial': imperialWeight},
    'bred_for': bredFor,
    'perfect_for': perfectFor,
    for (final entry in ratings.entries) entry.key.apiKey: entry.value,
    for (final entry in flags.entries) entry.key.apiKey: entry.value,
    for (final entry in sources.entries)
      entry.key.apiKey: entry.value.toString(),
  };
}
