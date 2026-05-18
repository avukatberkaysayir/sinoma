import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/video_segment_model.dart';
import '../../data/repositories/dictionary_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../../data/services/analytics_service.dart';
import 'ai_provider.dart';
import 'dictionary_provider.dart';
import 'user_provider.dart';

final videoRepositoryProvider = Provider<VideoRepository>((ref) {
  return VideoRepository(cache: ref.read(cacheServiceProvider));
});

// null = show all
final selectedCategoryProvider  = StateProvider<String?>((ref) => null);
final selectedLengthProvider    = StateProvider<String?>((ref) => null);
final selectedHskFilterProvider = StateProvider<int?>((ref) => null);
final selectedSearchProvider    = StateProvider<String?>((ref) => null);

final videoFeedProvider = FutureProvider<List<VideoSegmentModel>>((ref) async {
  final userHskLevel = ref.watch(currentHskLevelProvider);
  final hskFilter    = ref.watch(selectedHskFilterProvider);
  final category     = ref.watch(selectedCategoryProvider);
  final length       = ref.watch(selectedLengthProvider);
  final repo         = ref.read(videoRepositoryProvider);

  var segments = category != null
      ? await repo.loadSegmentsByCategory(userHskLevel, category)
      : await repo.loadSegmentsForLevel(userHskLevel);

  if (hskFilter != null) {
    segments = segments.where((s) => s.hskLevel == hskFilter).toList();
  }
  if (length != null) {
    segments = segments.where((s) => s.sentenceLength == length).toList();
  }
  return segments;
});

// Multilingual search over the already-fetched feed.
// CJK query  → filter by transcription / targetWords (character match).
// Latin query → resolve to Chinese via dictionary definitions (whole-word match only),
//               then filter by targetWords.
final _cjkRegex = RegExp(r'[一-鿿]');

// Checks if [word] appears as a whole token in [text] (splits on whitespace / punctuation).
bool _isWholeWordMatch(String text, String word) {
  final lw = word.toLowerCase();
  final tokens = text.toLowerCase().split(RegExp(r'[\s,;/()\-\.·]+'));
  return tokens.any((t) => t == lw);
}

final filteredVideoFeedProvider =
    FutureProvider<List<VideoSegmentModel>>((ref) async {
  final search   = ref.watch(selectedSearchProvider);
  final segments = await ref.watch(videoFeedProvider.future);

  if (search == null || search.isEmpty) return segments;
  final q = search.trim();
  if (q.isEmpty) return segments;

  if (_cjkRegex.hasMatch(q)) {
    return segments.where((s) =>
      s.transcription.contains(q) ||
      s.targetWords.any((w) => w.contains(q))
    ).toList();
  }

  // Latin (EN / TR) query: look up by definition, then keep only whole-word matches
  // to avoid "ot" matching "not", "robot", etc.
  final DictionaryRepository dictRepo = ref.read(dictionaryRepositoryProvider);
  final candidates = await dictRepo.searchWords(q, limit: 50);

  final matchedChars = candidates
      .where((m) =>
          _isWholeWordMatch(m.definitions.en, q) ||
          _isWholeWordMatch(m.definitions.tr, q))
      .map((m) => m.simplified)
      .toSet();

  if (matchedChars.isEmpty) return [];
  return segments.where((s) =>
    s.targetWords.any(matchedChars.contains)
  ).toList();
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

// ---------------------------------------------------------------------------
// Feed Playback — playlist-mode, drives VoscreenPlayerScreen
// ---------------------------------------------------------------------------

class FeedState {
  final List<VideoSegmentModel> segments;
  final int currentIndex;
  final VideoPlaybackStatus clipStatus;
  final bool wasCorrect;
  final int score;
  final int combo;
  final int replayCounter;

  const FeedState({
    this.segments = const [],
    this.currentIndex = 0,
    this.clipStatus = VideoPlaybackStatus.loading,
    this.wasCorrect = false,
    this.score = 0,
    this.combo = 0,
    this.replayCounter = 0,
  });

  VideoSegmentModel? get current =>
      segments.isEmpty ? null : segments[currentIndex];
  int get total => segments.length;
  bool get hasNext => currentIndex < segments.length - 1;
  bool get hasPrev => currentIndex > 0;

  FeedState copyWith({
    List<VideoSegmentModel>? segments,
    int? currentIndex,
    VideoPlaybackStatus? clipStatus,
    bool? wasCorrect,
    int? score,
    int? combo,
    int? replayCounter,
  }) =>
      FeedState(
        segments: segments ?? this.segments,
        currentIndex: currentIndex ?? this.currentIndex,
        clipStatus: clipStatus ?? this.clipStatus,
        wasCorrect: wasCorrect ?? this.wasCorrect,
        score: score ?? this.score,
        combo: combo ?? this.combo,
        replayCounter: replayCounter ?? this.replayCounter,
      );
}

class FeedNotifier extends StateNotifier<FeedState> {
  FeedNotifier() : super(const FeedState());

  void loadFeed(List<VideoSegmentModel> segments, int startIndex) {
    final clampedIndex =
        segments.isEmpty ? 0 : startIndex.clamp(0, segments.length - 1);
    state = FeedState(
      segments: segments,
      currentIndex: clampedIndex,
      clipStatus: VideoPlaybackStatus.playing,
    );
  }

  void activateQuiz() =>
      state = state.copyWith(clipStatus: VideoPlaybackStatus.quizActive);

  void recordAnswer(bool correct) {
    final newCombo = correct ? state.combo + 1 : 0;
    final points = correct ? 100 * (state.combo + 1).clamp(1, 3) : 0;
    state = state.copyWith(
      clipStatus: VideoPlaybackStatus.completed,
      wasCorrect: correct,
      combo: newCombo,
      score: state.score + points,
    );
  }

  void goNext() {
    if (!state.hasNext) return;
    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      clipStatus: VideoPlaybackStatus.playing,
      replayCounter: 0,
    );
  }

  void goPrev() {
    if (!state.hasPrev) return;
    state = state.copyWith(
      currentIndex: state.currentIndex - 1,
      clipStatus: VideoPlaybackStatus.playing,
      replayCounter: 0,
    );
  }

  void replay() => state = state.copyWith(
        clipStatus: VideoPlaybackStatus.playing,
        replayCounter: state.replayCounter + 1,
      );
}

final videoPlaylistProvider = StateNotifierProvider<FeedNotifier, FeedState>(
  (ref) => FeedNotifier(),
);
