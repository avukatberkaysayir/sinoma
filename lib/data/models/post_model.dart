import 'package:cloud_firestore/cloud_firestore.dart';

enum PostType { achievement, score, challenge, text }

class PostModel {
  final String postId;
  final String authorId;
  final String content;
  final String? attachmentUrl;
  final List<String> likes;
  final PostType postType;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  const PostModel({
    required this.postId,
    required this.authorId,
    required this.content,
    this.attachmentUrl,
    required this.likes,
    required this.postType,
    this.metadata = const {},
    required this.timestamp,
  });

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PostModel(
      postId: doc.id,
      authorId: data['authorId'] as String? ?? '',
      content: data['content'] as String? ?? '',
      attachmentUrl: data['attachmentUrl'] as String?,
      likes: List<String>.from(data['likes'] ?? []),
      postType: _parsePostType(data['postType'] as String?),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static PostType _parsePostType(String? value) => switch (value) {
        'achievement' => PostType.achievement,
        'score' => PostType.score,
        'challenge' => PostType.challenge,
        _ => PostType.text,
      };

  Map<String, dynamic> toFirestore() => {
        'authorId': authorId,
        'content': content,
        'attachmentUrl': attachmentUrl,
        'likes': likes,
        'postType': postType.name,
        'metadata': metadata,
        'timestamp': Timestamp.fromDate(timestamp),
      };

  int get likeCount => likes.length;
  bool hasLiked(String uid) => likes.contains(uid);
}
