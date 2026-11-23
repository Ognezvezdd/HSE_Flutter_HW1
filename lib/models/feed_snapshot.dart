import 'cat.dart';

class FeedSnapshot {
  const FeedSnapshot({this.likes = 0, this.cat});

  factory FeedSnapshot.fromJson(Map<String, dynamic> json) {
    final Object? likes = json['likes'];
    final Object? cat = json['cat'];
    if (json['version'] != 1 ||
        likes is! int ||
        likes < 0 ||
        (cat != null && cat is! Map<String, dynamic>)) {
      throw const FormatException('Invalid feed snapshot');
    }
    return FeedSnapshot(
      likes: likes,
      cat: cat == null ? null : Cat.fromJson(cat as Map<String, dynamic>),
    );
  }

  final int likes;
  final Cat? cat;

  Map<String, Object?> toJson() => {
    'version': 1,
    'likes': likes,
    'cat': cat?.toJson(),
  };
}
