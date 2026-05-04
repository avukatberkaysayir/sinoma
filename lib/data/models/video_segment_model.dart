import 'package:cloud_firestore/cloud_firestore.dart';

enum VideoSourceType { youtube, selfHosted }

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
    this.isActive = true,
    required this.createdAt,
  });

  factory VideoSegmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final sourceStr = data['sourceType'] as String? ?? 'youtube';
    return VideoSegmentModel(
      videoId: doc.id,
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
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
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
