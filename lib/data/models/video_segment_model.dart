enum VideoSourceType { youtube, selfHosted }

enum QuizCategory {
  baConstruct,
  beiPassive,
  shiDeEmphasis,
  conditional,
  contrast,
  causeEffect,
  guoExperience,
  biComparison,
  huiNengKeyi,
  yingDeiYao,
  xiangDasuan,
  questions,
  leCompletion,
  negation,
  timeWords,
  locationWords,
  general;

  static QuizCategory fromString(String value) =>
      QuizCategory.values.firstWhere(
        (c) => c.name == value,
        orElse: () => QuizCategory.general,
      );

  String get displayName => switch (this) {
        baConstruct   => '把字句',
        beiPassive    => '被动句',
        shiDeEmphasis => '是…的',
        conditional   => '条件句',
        contrast      => '转折句',
        causeEffect   => '因果句',
        guoExperience => '经历体 过',
        biComparison  => '比较句',
        huiNengKeyi   => '会/能/可以',
        yingDeiYao    => '应该/得/要',
        xiangDasuan   => '想/打算',
        questions     => '疑问句',
        leCompletion  => '完成体 了',
        negation      => '否定句',
        timeWords     => '时间表达',
        locationWords => '方位/地点',
        general       => '一般',
      };

  String get emoji => switch (this) {
        baConstruct   => '🫳',
        beiPassive    => '🔄',
        shiDeEmphasis => '💡',
        conditional   => '⚡',
        contrast      => '↔️',
        causeEffect   => '🔗',
        guoExperience => '🌍',
        biComparison  => '⚖️',
        huiNengKeyi   => '💪',
        yingDeiYao    => '📋',
        xiangDasuan   => '🎯',
        questions     => '❓',
        leCompletion  => '✅',
        negation      => '🚫',
        timeWords     => '⏰',
        locationWords => '📍',
        general       => '📖',
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
  final String lifeCategory; // 'daily_life' | 'business' | 'children'
  // Multi-tag classification (admin-editable). The single fields above stay as
  // the "primary" (first tag) for backward compatibility; these drive filtering.
  final List<int> hskLevels;
  final List<String> quizCategories;
  final List<String> lifeCategories;
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
    this.quizCategory = QuizCategory.general,
    this.lifeCategory = 'daily_life',
    this.hskLevels = const [],
    this.quizCategories = const [],
    this.lifeCategories = const [],
    this.isActive = true,
    required this.createdAt,
  });

  // Effective tag lists — fall back to the single primary value when the
  // multi-tag arrays are empty (older rows / cache).
  List<int> get hskLevelTags => hskLevels.isNotEmpty ? hskLevels : [hskLevel];
  List<String> get categoryTags =>
      quizCategories.isNotEmpty ? quizCategories : [quizCategory.name];
  List<String> get lifeTags =>
      lifeCategories.isNotEmpty ? lifeCategories : [lifeCategory];

  factory VideoSegmentModel.fromMap(Map<String, dynamic> data) {
    final sourceStr = data['source_type'] as String? ?? 'youtube';
    return VideoSegmentModel(
      videoId: data['id'] as String? ?? '',
      sourceType: sourceStr == 'self_hosted'
          ? VideoSourceType.selfHosted
          : VideoSourceType.youtube,
      youtubeId: data['youtube_id'] as String?,
      videoUrl: data['video_url'] as String?,
      startTime: (data['start_time'] as num?)?.toDouble() ?? 0,
      endTime: (data['end_time'] as num?)?.toDouble() ?? 0,
      hskLevel: (data['hsk_level'] as num?)?.toInt() ?? 1,
      transcription: data['transcription'] as String? ?? '',
      pinyin: data['pinyin'] as String? ?? '',
      targetWords: List<String>.from(data['target_words'] ?? []),
      quiz: QuizData.fromMap(data['quiz'] as Map<String, dynamic>? ?? {}),
      quizCategory: QuizCategory.fromString(data['quiz_category'] as String? ?? 'general'),
      lifeCategory: data['life_category'] as String? ?? 'daily_life',
      hskLevels: ((data['hsk_levels'] as List<dynamic>?) ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
      quizCategories: ((data['quiz_categories'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toList(),
      lifeCategories: ((data['life_categories'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toList(),
      isActive: data['is_active'] as bool? ?? true,
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : DateTime.now(),
    );
  }

  factory VideoSegmentModel.fromCache(String id, Map<String, dynamic> data) {
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
      quizCategory: QuizCategory.fromString(data['quizCategory'] as String? ?? 'general'),
      lifeCategory: data['lifeCategory'] as String? ?? 'daily_life',
      hskLevels: ((data['hskLevels'] as List<dynamic>?) ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
      quizCategories: ((data['quizCategories'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toList(),
      lifeCategories: ((data['lifeCategories'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toList(),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: data['createdAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': videoId,
        'source_type': sourceType == VideoSourceType.youtube ? 'youtube' : 'self_hosted',
        'youtube_id': youtubeId,
        'video_url': videoUrl,
        'start_time': startTime,
        'end_time': endTime,
        'hsk_level': hskLevel,
        'transcription': transcription,
        'pinyin': pinyin,
        'target_words': targetWords,
        'quiz': quiz.toMap(),
        'quiz_category': quizCategory.name,
        'life_category': lifeCategory,
        'hsk_levels': hskLevels,
        'quiz_categories': quizCategories,
        'life_categories': lifeCategories,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };

  Map<String, dynamic> toCacheMap() => {
        'sourceType': sourceType == VideoSourceType.youtube ? 'youtube' : 'self_hosted',
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
        'lifeCategory': lifeCategory,
        'hskLevels': hskLevels,
        'quizCategories': quizCategories,
        'lifeCategories': lifeCategories,
        'isActive': isActive,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  double get durationSeconds => endTime - startTime;
  bool get isYouTube => sourceType == VideoSourceType.youtube;
  bool get isSelfHosted => sourceType == VideoSourceType.selfHosted;

  int get hanCount =>
      RegExp(r'[一-鿿]').allMatches(transcription).length;

  String get sentenceLength {
    if (hanCount <= 5) return '1-5字';
    if (hanCount <= 10) return '6-10字';
    if (hanCount <= 15) return '11-15字';
    if (hanCount <= 20) return '16-20字';
    return '21字+';
  }
}

class QuizData {
  final String question;
  final String correctAnswer; // tr (top-level)
  final String wrongAnswer; // tr
  final String correctAnswerEn;
  final String wrongAnswerEn;

  const QuizData({
    required this.question,
    required this.correctAnswer,
    required this.wrongAnswer,
    this.correctAnswerEn = '',
    this.wrongAnswerEn = '',
  });

  factory QuizData.fromMap(Map<String, dynamic> map) {
    final en = (map['en'] as Map<String, dynamic>?) ?? const {};
    return QuizData(
      question: map['question'] as String? ?? '',
      correctAnswer: map['correctAnswer'] as String? ?? '',
      wrongAnswer: map['wrongAnswer'] as String? ?? '',
      correctAnswerEn: en['correctAnswer'] as String? ?? '',
      wrongAnswerEn: en['wrongAnswer'] as String? ?? '',
    );
  }

  // Resolve options for the UI language; fall back to Turkish (the always-saved
  // top-level fields) when the requested language has no saved text.
  String correctFor(String lang) =>
      (lang == 'en' && correctAnswerEn.isNotEmpty) ? correctAnswerEn : correctAnswer;
  String wrongFor(String lang) =>
      (lang == 'en' && wrongAnswerEn.isNotEmpty) ? wrongAnswerEn : wrongAnswer;

  Map<String, dynamic> toMap() => {
        'question': question,
        'correctAnswer': correctAnswer,
        'wrongAnswer': wrongAnswer,
        if (correctAnswerEn.isNotEmpty || wrongAnswerEn.isNotEmpty)
          'en': {'correctAnswer': correctAnswerEn, 'wrongAnswer': wrongAnswerEn},
      };
}
