import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/character_analyzer.dart';
import '../../data/models/dictionary_model.dart';
import '../../data/models/video_segment_model.dart';
import 'ai_provider.dart';
import 'auth_provider.dart';
import 'dictionary_provider.dart';
import 'user_provider.dart';
import 'video_provider.dart';

// =============================================================================
// MANDARIN DUEL
// =============================================================================

class DuelRound {
  final String videoId;
  final String question;
  final List<String> choices; // pre-shuffled at construction — never reshuffles
  final String correctAnswer;
  final QuizCategory category;
  final List<String> targetWords; // wordIds for "save to dictionary"

  DuelRound({
    required this.videoId,
    required this.question,
    required this.choices,
    required this.correctAnswer,
    required this.category,
    required this.targetWords,
  });

  factory DuelRound.fromSegment(VideoSegmentModel segment) {
    final choices = [segment.quiz.correctAnswer, segment.quiz.wrongAnswer]
      ..shuffle();
    return DuelRound(
      videoId: segment.videoId,
      question: segment.quiz.question,
      choices: choices,
      correctAnswer: segment.quiz.correctAnswer,
      category: segment.quizCategory,
      targetWords: segment.targetWords,
    );
  }
}

enum DuelStatus { loading, wheelSpinning, playing, answered, finished, error }

class DuelState {
  final DuelStatus status;
  final List<DuelRound> rounds;
  final int currentRoundIndex;
  final String? selectedAnswer; // null = unanswered, '' = timed out
  final int score;
  final int botScore; // simulated opponent score
  final int combo;
  final int livesRemaining;
  final int secondsRemaining;
  final bool wordsSavedForCurrentRound;
  final String? error;

  const DuelState({
    required this.status,
    this.rounds = const [],
    this.currentRoundIndex = 0,
    this.selectedAnswer,
    this.score = 0,
    this.botScore = 0,
    this.combo = 0,
    this.livesRemaining = 3,
    this.secondsRemaining = 10,
    this.wordsSavedForCurrentRound = false,
    this.error,
  });

  DuelRound? get currentRound =>
      rounds.isEmpty || currentRoundIndex >= rounds.length
          ? null
          : rounds[currentRoundIndex];

  // null = not yet answered, true/false = result, false also covers timeout ('').
  bool? get wasCorrect {
    if (selectedAnswer == null) return null;
    if (selectedAnswer!.isEmpty) return false;
    return selectedAnswer == currentRound?.correctAnswer;
  }

  bool get isLastRound => currentRoundIndex >= rounds.length - 1;
  int get totalRounds => rounds.length;
}

class MandarinDuelNotifier extends StateNotifier<DuelState> {
  final int hskLevel;
  final Ref _ref;
  Timer? _timer;
  final _rng = Random();

  MandarinDuelNotifier(this._ref, this.hskLevel)
      : super(const DuelState(status: DuelStatus.loading));

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> startGame() async {
    _timer?.cancel();
    state = const DuelState(status: DuelStatus.loading);
    try {
      final segments = await _ref
          .read(videoRepositoryProvider)
          .loadSegmentsForGame(hskLevel);

      if (segments.isEmpty) {
        state = DuelState(
          status: DuelStatus.error,
          error: 'No questions available at HSK $hskLevel.',
        );
        return;
      }

      final rounds = segments.map(DuelRound.fromSegment).toList();
      _ref.read(analyticsServiceProvider).logGameStarted('mandarin_duel', hskLevel);
      state = DuelState(
        status: DuelStatus.wheelSpinning,
        rounds: rounds,
        livesRemaining: 3,
        secondsRemaining: 10,
      );
    } catch (e) {
      state = DuelState(status: DuelStatus.error, error: e.toString());
    }
  }

  // Called by UI after the wheel animation completes.
  void beginQuestion() {
    final s = state;
    if (s.status != DuelStatus.wheelSpinning) return;
    state = DuelState(
      status: DuelStatus.playing,
      rounds: s.rounds,
      currentRoundIndex: s.currentRoundIndex,
      score: s.score,
      botScore: s.botScore,
      combo: s.combo,
      livesRemaining: s.livesRemaining,
      secondsRemaining: 10,
    );
    _startTimer();
  }

  void submitAnswer(String answer) {
    _timer?.cancel();
    final s = state;
    if (s.status != DuelStatus.playing || s.currentRound == null) return;

    final correct = answer == s.currentRound!.correctAnswer;
    final newCombo = correct ? s.combo + 1 : 0;
    final newScore =
        correct ? s.score + 100 * newCombo.clamp(1, 3) : s.score;
    final newLives = correct ? s.livesRemaining : s.livesRemaining - 1;
    final newBotScore = s.botScore + _rng.nextInt(80) + 40;

    state = DuelState(
      status: newLives <= 0 ? DuelStatus.finished : DuelStatus.answered,
      rounds: s.rounds,
      currentRoundIndex: s.currentRoundIndex,
      selectedAnswer: answer,
      score: newScore,
      botScore: newBotScore,
      combo: newCombo,
      livesRemaining: newLives,
      secondsRemaining: s.secondsRemaining,
    );
  }

  void advanceRound() {
    final s = state;
    if (s.status != DuelStatus.answered) return;
    final nextIndex = s.currentRoundIndex + 1;

    if (nextIndex >= s.rounds.length) {
      _ref.read(analyticsServiceProvider).logGameCompleted(
            gameType: 'mandarin_duel',
            hskLevel: hskLevel,
            score: s.score,
            roundsPlayed: nextIndex,
            survived: s.livesRemaining > 0,
          );
      state = DuelState(
        status: DuelStatus.finished,
        rounds: s.rounds,
        currentRoundIndex: s.currentRoundIndex,
        score: s.score,
        botScore: s.botScore,
        combo: s.combo,
        livesRemaining: s.livesRemaining,
      );
      return;
    }

    state = DuelState(
      status: DuelStatus.wheelSpinning,
      rounds: s.rounds,
      currentRoundIndex: nextIndex,
      score: s.score,
      botScore: s.botScore,
      combo: s.combo,
      livesRemaining: s.livesRemaining,
      secondsRemaining: 10,
    );
  }

  // Restores 1 life after a rewarded ad. Only valid when game over due to no lives.
  void restoreOneLife() {
    final s = state;
    if (s.status != DuelStatus.finished || s.livesRemaining > 0) return;
    state = DuelState(
      status: DuelStatus.answered,
      rounds: s.rounds,
      currentRoundIndex: s.currentRoundIndex,
      selectedAnswer: s.selectedAnswer,
      score: s.score,
      botScore: s.botScore,
      combo: 0,
      livesRemaining: 1,
      secondsRemaining: 0,
      wordsSavedForCurrentRound: s.wordsSavedForCurrentRound,
    );
  }

  // Saves all targetWords from the current wrong-answer round to user's learnedWords.
  Future<void> saveTargetWords() async {
    final s = state;
    if (s.wordsSavedForCurrentRound || s.currentRound == null) return;
    final words = s.currentRound!.targetWords;
    if (words.isEmpty) return;

    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;

    for (final wordId in words) {
      try {
        await _ref.read(userRepositoryProvider).markWordLearned(uid, wordId);
      } catch (_) {
        // Best-effort: skip individual failures.
      }
    }

    if (!mounted) return;
    final current = state;
    state = DuelState(
      status: current.status,
      rounds: current.rounds,
      currentRoundIndex: current.currentRoundIndex,
      selectedAnswer: current.selectedAnswer,
      score: current.score,
      botScore: current.botScore,
      combo: current.combo,
      livesRemaining: current.livesRemaining,
      secondsRemaining: current.secondsRemaining,
      wordsSavedForCurrentRound: true,
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final s = state;
      if (s.status != DuelStatus.playing) {
        _timer?.cancel();
        return;
      }
      if (s.secondsRemaining <= 1) {
        _timer?.cancel();
        _handleTimeout();
      } else {
        state = DuelState(
          status: s.status,
          rounds: s.rounds,
          currentRoundIndex: s.currentRoundIndex,
          score: s.score,
          botScore: s.botScore,
          combo: s.combo,
          livesRemaining: s.livesRemaining,
          secondsRemaining: s.secondsRemaining - 1,
        );
      }
    });
  }

  void _handleTimeout() {
    final s = state;
    final newLives = s.livesRemaining - 1;
    final newBotScore = s.botScore + _rng.nextInt(80) + 40;
    state = DuelState(
      status: newLives <= 0 ? DuelStatus.finished : DuelStatus.answered,
      rounds: s.rounds,
      currentRoundIndex: s.currentRoundIndex,
      selectedAnswer: '', // empty = timed out (wrong answer)
      score: s.score,
      botScore: newBotScore,
      combo: 0,
      livesRemaining: newLives,
      secondsRemaining: 0,
    );
  }
}

final mandarinDuelProvider = StateNotifierProvider.autoDispose
    .family<MandarinDuelNotifier, DuelState, int>(
  (ref, hskLevel) => MandarinDuelNotifier(ref, hskLevel),
);

// =============================================================================
// HANZI BUILD
// =============================================================================

class HanziRound {
  final String wordId;
  final String simplified;
  final String pinyin;
  final WordDefinitions definitions;
  final List<String> tiles; // shuffled at construction — includes 4 decoys
  final List<String> correctRadicals;

  const HanziRound({
    required this.wordId,
    required this.simplified,
    required this.pinyin,
    required this.definitions,
    required this.tiles,
    required this.correctRadicals,
  });
}

enum HanziBuildStatus { loading, playing, answered, finished, error }

class HanziBuildState {
  final HanziBuildStatus status;
  final List<HanziRound> rounds;
  final int currentRoundIndex;
  final List<String> selectedTiles;
  final bool? wasCorrect;
  final int score;
  final int combo;
  final int secondsRemaining;
  final bool showingHint;
  final String? error;

  const HanziBuildState({
    required this.status,
    this.rounds = const [],
    this.currentRoundIndex = 0,
    this.selectedTiles = const [],
    this.wasCorrect,
    this.score = 0,
    this.combo = 0,
    this.secondsRemaining = 20,
    this.showingHint = false,
    this.error,
  });

  HanziRound? get currentRound =>
      rounds.isEmpty || currentRoundIndex >= rounds.length
          ? null
          : rounds[currentRoundIndex];

  int get totalRounds => rounds.length;
}

class HanziBuildNotifier extends StateNotifier<HanziBuildState> {
  final int hskLevel;
  final Ref _ref;
  Timer? _timer;

  HanziBuildNotifier(this._ref, this.hskLevel)
      : super(const HanziBuildState(status: HanziBuildStatus.loading));

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> startGame() async {
    _timer?.cancel();
    state = const HanziBuildState(status: HanziBuildStatus.loading);
    try {
      final words = await _ref
          .read(dictionaryRepositoryProvider)
          .loadWordsForLevel(hskLevel);

      if (words.isEmpty) {
        state = HanziBuildState(
          status: HanziBuildStatus.error,
          error: 'No character data available at HSK $hskLevel.',
        );
        return;
      }

      final radicalMap = <String, List<String>>{};
      for (final word in words) {
        if (word.simplified.length == 1 && word.radicals.isNotEmpty) {
          radicalMap[word.simplified] = word.radicals;
        }
      }

      if (radicalMap.isEmpty) {
        state = HanziBuildState(
          status: HanziBuildStatus.error,
          error: 'No radical data available at HSK $hskLevel.',
        );
        return;
      }

      final analyzer = CharacterAnalyzer(radicalMap);
      final rounds = words
          .where((w) =>
              w.simplified.length == 1 && analyzer.hasRadicals(w.simplified))
          .map((w) => HanziRound(
                wordId: w.wordId,
                simplified: w.simplified,
                pinyin: w.pinyin,
                definitions: w.definitions,
                tiles: analyzer.buildShuffledTiles(w.simplified, 4),
                correctRadicals: analyzer.buildRadicalList(w.simplified),
              ))
          .toList();

      if (rounds.isEmpty) {
        state = HanziBuildState(
          status: HanziBuildStatus.error,
          error: 'No playable characters at HSK $hskLevel.',
        );
        return;
      }

      _ref.read(analyticsServiceProvider).logGameStarted('hanzi_build', hskLevel);
      state = HanziBuildState(
        status: HanziBuildStatus.playing,
        rounds: rounds,
        secondsRemaining: 20,
      );
      _startMoveTimer();
    } catch (e) {
      state =
          HanziBuildState(status: HanziBuildStatus.error, error: e.toString());
    }
  }

  void toggleTile(String tile) {
    final s = state;
    if (s.status != HanziBuildStatus.playing) return;

    final selected = List<String>.from(s.selectedTiles);
    if (selected.contains(tile)) {
      selected.remove(tile);
    } else {
      selected.add(tile);
    }

    state = HanziBuildState(
      status: s.status,
      rounds: s.rounds,
      currentRoundIndex: s.currentRoundIndex,
      selectedTiles: selected,
      score: s.score,
      combo: s.combo,
      secondsRemaining: s.secondsRemaining,
    );
  }

  void submitAnswer() {
    _timer?.cancel();
    final s = state;
    if (s.status != HanziBuildStatus.playing || s.currentRound == null) return;

    final correct = List<String>.from(s.currentRound!.correctRadicals)..sort();
    final selected = List<String>.from(s.selectedTiles)..sort();
    final wasCorrect = selected.length == correct.length &&
        List.generate(correct.length, (i) => selected[i] == correct[i])
            .every((v) => v);

    final newCombo = wasCorrect ? s.combo + 1 : 0;
    final newScore =
        wasCorrect ? s.score + 100 * newCombo.clamp(1, 3) : s.score;

    state = HanziBuildState(
      status: HanziBuildStatus.answered,
      rounds: s.rounds,
      currentRoundIndex: s.currentRoundIndex,
      selectedTiles: s.selectedTiles,
      wasCorrect: wasCorrect,
      score: newScore,
      combo: newCombo,
    );
  }

  void advanceRound() {
    final s = state;
    if (s.status != HanziBuildStatus.answered) return;
    final nextIndex = s.currentRoundIndex + 1;

    if (nextIndex >= s.rounds.length) {
      _ref.read(analyticsServiceProvider).logGameCompleted(
            gameType: 'hanzi_build',
            hskLevel: hskLevel,
            score: s.score,
            roundsPlayed: nextIndex,
            survived: true,
          );
      state = HanziBuildState(
        status: HanziBuildStatus.finished,
        rounds: s.rounds,
        currentRoundIndex: s.currentRoundIndex,
        score: s.score,
        combo: s.combo,
      );
      return;
    }

    state = HanziBuildState(
      status: HanziBuildStatus.playing,
      rounds: s.rounds,
      currentRoundIndex: nextIndex,
      score: s.score,
      combo: s.combo,
      secondsRemaining: 20,
    );
    _startMoveTimer();
  }

  void requestHint() {
    final s = state;
    if (s.status != HanziBuildStatus.playing) return;
    state = HanziBuildState(
      status: s.status,
      rounds: s.rounds,
      currentRoundIndex: s.currentRoundIndex,
      selectedTiles: s.selectedTiles,
      score: s.score,
      combo: s.combo,
      secondsRemaining: s.secondsRemaining,
      showingHint: true,
    );
  }

  void dismissHint() {
    final s = state;
    state = HanziBuildState(
      status: s.status,
      rounds: s.rounds,
      currentRoundIndex: s.currentRoundIndex,
      selectedTiles: s.selectedTiles,
      wasCorrect: s.wasCorrect,
      score: s.score,
      combo: s.combo,
      secondsRemaining: s.secondsRemaining,
      showingHint: false,
    );
  }

  void _startMoveTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final s = state;
      if (s.status != HanziBuildStatus.playing) {
        _timer?.cancel();
        return;
      }
      if (s.secondsRemaining <= 1) {
        _timer?.cancel();
        _handleTimeout();
      } else {
        state = HanziBuildState(
          status: s.status,
          rounds: s.rounds,
          currentRoundIndex: s.currentRoundIndex,
          selectedTiles: s.selectedTiles,
          score: s.score,
          combo: s.combo,
          secondsRemaining: s.secondsRemaining - 1,
          showingHint: s.showingHint,
        );
      }
    });
  }

  void _handleTimeout() {
    final s = state;
    state = HanziBuildState(
      status: HanziBuildStatus.answered,
      rounds: s.rounds,
      currentRoundIndex: s.currentRoundIndex,
      selectedTiles: s.selectedTiles,
      wasCorrect: false,
      score: s.score,
      combo: 0,
      secondsRemaining: 0,
    );
  }
}

final hanziBuildProvider = StateNotifierProvider.autoDispose
    .family<HanziBuildNotifier, HanziBuildState, int>(
  (ref, hskLevel) => HanziBuildNotifier(ref, hskLevel),
);
