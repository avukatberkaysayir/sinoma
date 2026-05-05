import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/video_segment_model.dart';
import '../../data/repositories/video_repository.dart';
import '../../data/services/analytics_service.dart';
import 'ai_provider.dart';
import 'dictionary_provider.dart';
import 'user_provider.dart';

final videoRepositoryProvider = Provider<VideoRepository>((ref) {
  return VideoRepository(cache: ref.read(cacheServiceProvider));
});

final videoFeedProvider = FutureProvider<List<VideoSegmentModel>>((ref) async {
  final hskLevel = ref.watch(currentHskLevelProvider);
  return ref.read(videoRepositoryProvider).loadSegmentsForLevel(hskLevel);
});

// ---------------------------------------------------------------------------
// Video Playback State Machine
// ---------------------------------------------------------------------------

enum VideoPlaybackStatus { loading, playing, quizActive, completed }

class VideoPlaybackState {
  final VideoSegmentModel? segment;
  final VideoPlaybackStatus status;
  final bool wasCorrect;
  final int combo;
  final int hearts;
  final int score;

  const VideoPlaybackState({
    this.segment,
    this.status = VideoPlaybackStatus.loading,
    this.wasCorrect = false,
    this.combo = 0,
    this.hearts = 3,
    this.score = 0,
  });

  VideoPlaybackState copyWith({
    VideoSegmentModel? segment,
    VideoPlaybackStatus? status,
    bool? wasCorrect,
    int? combo,
    int? hearts,
    int? score,
  }) {
    return VideoPlaybackState(
      segment: segment ?? this.segment,
      status: status ?? this.status,
      wasCorrect: wasCorrect ?? this.wasCorrect,
      combo: combo ?? this.combo,
      hearts: hearts ?? this.hearts,
      score: score ?? this.score,
    );
  }

  static const int basePoints = 100;
  static const int maxCombo = 3;

  int get comboMultiplier => (combo).clamp(1, maxCombo);
  bool get isAlive => hearts > 0;
}

class VideoPlaybackNotifier extends StateNotifier<VideoPlaybackState> {
  VideoPlaybackNotifier(this._analytics) : super(const VideoPlaybackState());

  final AnalyticsService _analytics;

  void loadSegment(VideoSegmentModel segment) {
    state = state.copyWith(
      segment: segment,
      status: VideoPlaybackStatus.playing,
    );
    _analytics.logVideoStarted(segment.videoId, segment.hskLevel);
  }

  void activateQuiz() {
    state = state.copyWith(status: VideoPlaybackStatus.quizActive);
  }

  void recordCorrectAnswer() {
    final newCombo = state.combo + 1;
    final points = VideoPlaybackState.basePoints * state.comboMultiplier;
    final seg = state.segment;
    state = state.copyWith(
      status: VideoPlaybackStatus.completed,
      wasCorrect: true,
      combo: newCombo,
      score: state.score + points,
    );
    if (seg != null) {
      _analytics.logVideoCompleted(
        videoId: seg.videoId,
        hskLevel: seg.hskLevel,
        wasCorrect: true,
        quizCategory: seg.quizCategory.name,
      );
    }
  }

  void recordWrongAnswer() {
    final seg = state.segment;
    state = state.copyWith(
      status: VideoPlaybackStatus.completed,
      wasCorrect: false,
      combo: 0,
      hearts: (state.hearts - 1).clamp(0, 3),
    );
    if (seg != null) {
      _analytics.logVideoCompleted(
        videoId: seg.videoId,
        hskLevel: seg.hskLevel,
        wasCorrect: false,
        quizCategory: seg.quizCategory.name,
      );
    }
  }

  void reset() {
    state = const VideoPlaybackState();
  }
}

final videoPlaybackProvider =
    StateNotifierProvider<VideoPlaybackNotifier, VideoPlaybackState>(
  (ref) => VideoPlaybackNotifier(ref.read(analyticsServiceProvider)),
);
