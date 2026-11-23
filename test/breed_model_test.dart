import 'package:cat_tinder/models/breed.dart';
import 'package:cat_tinder/models/feed_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  test('core-only and legacy saved breeds remain readable', () {
    final legacy = FeedSnapshot.fromJson({
      'version': 1,
      'likes': 9,
      'cat': catJson('old'),
    });
    expect(legacy.likes, 9);
    expect(legacy.cat?.id, 'old');
    expect(legacy.cat?.breed.id, isNull);
    expect(legacy.cat?.breed.ratings, isEmpty);
  });

  test('full fields, boolean and numeric flags survive serialization', () {
    final breed = Breed.fromJson({
      ...breedJson('abys', 'Abyssinian'),
      'wikipedia_url': 'https://en.wikipedia.org/wiki/Abyssinian_cat',
    });
    expect(breed.lifeSpan, '12 - 15');
    expect(breed.metricWeight, '3 - 5');
    expect(breed.ratings[BreedRating.intelligence], 4);
    expect(breed.flags[BreedFlag.hairless], isFalse);
    expect(breed.flags[BreedFlag.natural], isTrue);
    expect(Breed.fromJson(breed.toJson()).toJson(), breed.toJson());
  });

  for (final entry in <String, Object>{
    'intelligence': 'very high',
    'hairless': 2,
    'energy_level': 8,
    'weight': 'unknown',
  }.entries) {
    test('rejects malformed ${entry.key}', () {
      expect(
        () => Breed.fromJson({
          ...breedJson('abys', 'Abyssinian'),
          entry.key: entry.value,
        }),
        throwsFormatException,
      );
    });
  }
}
