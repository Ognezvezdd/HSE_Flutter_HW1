import 'package:flutter/material.dart';

import '../models/breed.dart';
import '../widgets/breed_information.dart';

class BreedDetailsScreen extends StatelessWidget {
  const BreedDetailsScreen({super.key, required this.breed, this.photo});

  final Breed breed;
  final ImageProvider? photo;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(breed.name),
      leading: IconButton(
        key: const Key('details_back_button'),
        tooltip: 'Назад',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        key: const Key('breed_details_scroll'),
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (photo case final image?) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 1.3,
                      child: Image(
                        image: image,
                        fit: BoxFit.contain,
                        key: const Key('cat_detail_image'),
                        semanticLabel: 'Кот породы ${breed.name}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                BreedInformation(breed: breed),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
