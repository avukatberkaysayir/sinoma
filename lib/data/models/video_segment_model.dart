import 'package:cloud_firestore/cloud_firestore.dart';

enum VideoSourceType { youtube, selfHosted }

// 6 categories used by the Mandarin Duel category wheel.
enum QuizCategory {
  vocabulary,
  grammar,
  listening,
  characters,
  conversation,
  culture;

  static QuizCategory fromString(String value) =>
      QuizCategory.values.firstWhere(
        (c) => c.name == value,
        orElse: () => QuizCategory.vocabulary,
      );

  String get displayName => switch (this) {
        vocabulary => 'Vocabulary',
        grammar => 'Grammar',
        listening => 'Listening',
        characters => 'Characters',
        conversation => 'Daily Conversation',
        culture => 'Culture',
      };

  String get emoji => switch (this) {
        vocabulary => '📚',
        grammar => '📝',
        listening => '🎧',
        characters => '🖊',
        conversation => '💬',
        culture => '🏮',
      };
}

class VideoSegmentModel {
  final String videoId;
  final VideoSourceType sourceType;
  final String? youtubeId;
  final String? videoUrl;
  final double startTime;
  final double endTime;
  final int hskLevel;
  final String transcription;
  final String pinyin;
  final List<String> targetWords;
  final QuizData quiz;
  final QuizCategory quizCategory;
  final bool isActive;
  final DateTime createdAt;

  const VideoSegmentModel({
    required this.videoId,
    required this.sourceType,
    this.youtubeId,
    this.videoUrl,
    required this.startTime,
    required this.endTime,
    required this.hskLevel,
    required this.transcription,
    required this.pinyin,
    required this.targetWords,
    required this.quiz,
    this.quizCategory = QuizCategory.vocabulary,
    this.isActive = true,
    required this.createdAt,
  });

  factory VideoSegmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VideoSegmentModel._fromMap(doc.id, data,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now());
  }

  factory VideoSegmentModel.fromCache(String id, Map<String, dynamic> data) {
    return VideoSegmentModel._fromMap(id, data,
        createdAt: data['createdAt'] is int
            ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int)
            : DateTime.now());
  }

  factory VideoSegmentModel._fromMap(
    String id,
    Map<String, dynamic> data, {
    required DateTime createdAt,
  }) {
    final sourceStr = data['sourceType'] as String? ?? 'youtube';
    return VideoSegmentModel(
      videoId: id,
      sourceType: sourceStr == 'self_hosted'
          ? VideoSourceType.selfHosted
          : VideoSourceType.youtube,
      youtubeId: data['youtubeId'] as String?,
      videoUrl: data['videoUrl'] as String?,
      startTime: (data['startTime'] as num?)?.toDouble() ?? 0,
      endTime: (data['endTime'] as num?)?.toDouble() ?? 0,
      hskLevel: (data['hskLevel'] as num?)?.toInt() ?? 1,
      transcription: data['transcription'] as String? ?? '',
      pinyin: data['pinyin'] as String? ?? '',
      targetWords: List<String>.from(data['targetWords'] ?? []),
      quiz: QuizData.fromMap(data['quiz'] as Map<String, dynamic>? ?? {}),
      quizCategory: QuizCategory.fromString(
          data['quizCategory'] as String? ?? 'vocabulary'),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'sourceType':
            sourceType == VideoSourceType.youtube ? 'youtube' : 'self_hosted',
        'youtubeId': youtubeId,
        'videoUrl': videoUrl,
        'startTime': startTime,
        'endTime': endTime,
        'hskLevel': hskLevel,
        'transcription': transcription,
        'pinyin': pinyin,
        'targetWords': targetWords,
        'quiz': quiz.toMap(),
        'quizCategory': quizCategory.name,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  Map<String, dynamic> toCacheMap() => {
        'sourceType':
            sourceType == VideoSourceType.youtube ? 'youtube' : 'self_hosted',
        'youtubeId': youtubeId,
        'videoUrl': videoUrl,
        'startTime': startTime,
        'endTime': endTime,
        'hskLevel': hskLevel,
        'transcription': transcription,
        'pinyin': pinyin,
        'targetWords': targetWords,
        'quiz': quiz.toMap(),
        'quizCategory': quizCategory.name,
        'isActive': isActive,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  double get durationSeconds => endTime - startTime;
  bool get isYouTube => sourceType == VideoSourceType.youtube;
  bool get isSelfHosted => sourceType == VideoSourceType.selfHosted;
}

class QuizData {
  final String question;
  final String correctAnswer;
  final String wrongAnswer;

  const QuizData({
    required this.question,
    required this.correctAnswer,
    required this.wrongAnswer,
  });

  factory QuizData.fromMap(Map<String, dynamic> map) => QuizData(
        question: map['question'] as String? ?? '',
        correctAnswer: map['correctAnswer'] as String? ?? '',
        wrongAnswer: map['wrongAnswer'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'question': question,
        'correctAnswer': correctAnswer,
        'wrongAnswer': wrongAnswer,
      };
}
