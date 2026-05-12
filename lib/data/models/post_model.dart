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

  factory PostModel.fromMap(Map<String, dynamic> data) => PostModel(
        postId: data['id'] as String? ?? '',
        authorId: data['author_id'] as String? ?? '',
        content: data['content'] as String? ?? '',
        attachmentUrl: data['attachment_url'] as String?,
        likes: List<String>.from(data['likes'] ?? []),
        postType: _parsePostType(data['post_type'] as String?),
        metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
        timestamp: data['timestamp'] != null
            ? DateTime.parse(data['timestamp'] as String)
            : DateTime.now(),
      );

  static PostType _parsePostType(String? value) => switch (value) {
        'achievement' => PostType.achievement,
        'score' => PostType.score,
        'challenge' => PostType.challenge,
        _ => PostType.text,
      };

  Map<String, dynamic> toMap() => {
        'id': postId,
        'author_id': authorId,
        'content': content,
        'attachment_url': attachmentUrl,
        'likes': likes,
        'post_type': postType.name,
        'metadata': metadata,
        'timestamp': timestamp.toIso8601String(),
      };

  int get likeCount => likes.length;
  bool hasLiked(String uid) => likes.contains(uid);
}
