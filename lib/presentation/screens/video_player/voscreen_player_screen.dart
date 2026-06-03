import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/video_segment_model.dart';
import '../../providers/video_provider.dart';
import '../../widgets/common/word_detail_sheet.dart';
import '../../widgets/video/direct_youtube_player.dart';

// Voscreen-style playlist player.
// Reads from videoPlaylistProvider — call videoPlaylistProvider.notifier.loadFeed() before pushing /play.
// Layout: top bar → video 16:9 → Chinese text → pinyin → quiz/nav area.

class VoscreenPlayerScreen extends ConsumerWidget {
  const VoscreenPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(videoPlaylistProvider);

    if (feed.segments.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No videos loaded.',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go back')),
            ],
          ),
        ),
      );
    }

    final segment = feed.current!;
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(feed: feed),
            Expanded(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _PlayerColumn(
                              feed: feed, segment: segment),
                        ),
                        Container(
                          width: 1,
                          color: Colors.white12,
                        ),
                        Expanded(
                          flex: 3,
                          child: _InfoSidePanel(segment: segment),
                        ),
                      ],
                    )
                  : _PlayerColumn(feed: feed, segment: segment),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  final FeedState feed;
  const _TopBar({required this.feed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segment = feed.current!;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => context.pop(),
          ),
          const Spacer(),
          // Progress counter
          Text(
            '${feed.currentIndex + 1} / ${feed.total}',
            style: const TextStyle(
                color: Colors.white60,
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          // HSK badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.forHskLevel(segment.hskLevel),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'HSK ${segment.hskLevel}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          // Category badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              segment.quizCategory.displayName,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          const SizedBox(width: 4),
          // Prev / Next nav
          IconButton(
            icon: const Icon(Icons.skip_previous, color: Colors.white38),
            onPressed: feed.hasPrev
                ? () => ref.read(videoPlaylistProvider.notifier).goPrev()
                : null,
            tooltip: 'Previous clip',
          ),
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.white38),
            onPressed: feed.hasNext
                ? () => ref.read(videoPlaylistProvider.notifier).goNext()
                : null,
            tooltip: 'Next clip',
          ),
        ],
      ),
    );
  }
}

// ── Player column (video + text + action) ────────────────────────────────────

class _PlayerColumn extends ConsumerStatefulWidget {
  final FeedState feed;
  final VideoSegmentModel segment;

  const _PlayerColumn({required this.feed, required this.segment});

  @override
  ConsumerState<_PlayerColumn> createState() => _PlayerColumnState();
}

class _PlayerColumnState extends ConsumerState<_PlayerColumn> {
  String? _selectedAnswer;
  DirectYouTubeController _ytCtrl = DirectYouTubeController();

  @override
  void didUpdateWidget(_PlayerColumn old) {
    super.didUpdateWidget(old);
    if (old.segment.videoId != widget.segment.videoId ||
        old.feed.replayCounter != widget.feed.replayCounter) {
      _selectedAnswer = null;
      // New video segment: fresh controller so the old iframe is fully released.
      if (old.segment.videoId != widget.segment.videoId) {
        _ytCtrl = DirectYouTubeController();
      }
      // Same segment replay: replayCount prop change triggers didUpdateWidget
      // inside DirectYouTubePlayer → seekTo + playVideo, no overlay re-shown.
    }
  }

  void _handleAnswer(bool isCorrect, String answer) {
    if (_selectedAnswer != null) return;
    setState(() => _selectedAnswer = answer);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      ref.read(videoPlaylistProvider.notifier).recordAnswer(isCorrect);
    });
  }

  void _showWordDetail(String wordId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WordDetailSheet(
        wordId: wordId,
        transcription: widget.segment.transcription,
        hskLevel: widget.segment.hskLevel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = widget.feed;
    final segment = widget.segment;
    final quiz = segment.quiz;
    final status = feed.clipStatus;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Video player ────────────────────────────────────────────────
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: DirectYouTubePlayer(
              key: ValueKey('${segment.videoId}-${segment.startTime}'),
              videoId: segment.youtubeId ?? '',
              startTime: segment.startTime,
              endTime: segment.endTime,
              hskLevel: segment.hskLevel,
              replayCount: feed.replayCounter,
              controller: _ytCtrl,
              onSegmentEnded: () =>
                  ref.read(videoPlaylistProvider.notifier).activateQuiz(),
            ),
          ),
        ),

        // ── Transcription ───────────────────────────────────────────────
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                children: [
                  // Chinese characters — tappable target words
                  _TappableTranscription(
                    transcription: segment.transcription,
                    targetWords: segment.targetWords,
                    onWordTapped: _showWordDetail,
                  ),
                  const SizedBox(height: 10),
                  // Pinyin
                  Text(
                    segment.pinyin,
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 15,
                        letterSpacing: 0.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Action area ─────────────────────────────────────────────────
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: switch (status) {
                VideoPlaybackStatus.playing ||
                VideoPlaybackStatus.loading =>
                  _WatchHint(score: feed.score),
                VideoPlaybackStatus.quizActive => _QuizPanel(
                    quiz: quiz,
                    selectedAnswer: _selectedAnswer,
                    onAnswer: _handleAnswer,
                  ),
                VideoPlaybackStatus.completed => _CompletionPanel(
                    feed: feed,
                    onReplay: () {
                      setState(() => _selectedAnswer = null);
                      ref.read(videoPlaylistProvider.notifier).replay();
                    },
                    onNext: () {
                      setState(() => _selectedAnswer = null);
                      ref.read(videoPlaylistProvider.notifier).goNext();
                    },
                  ),
              },
            ),
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

// ── Tappable Chinese transcription ───────────────────────────────────────────

class _TappableTranscription extends StatelessWidget {
  final String transcription;
  final List<String> targetWords;
  final void Function(String wordId) onWordTapped;

  const _TappableTranscription({
    required this.transcription,
    required this.targetWords,
    required this.onWordTapped,
  });

  @override
  Widget build(BuildContext context) {
    if (targetWords.isEmpty) {
      return Text(
        transcription,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.4),
        textAlign: TextAlign.center,
      );
    }

    // Sort target words by first occurrence in transcription.
    // Skip the multi-sentence line-break sentinel.
    final positioned = targetWords
        .where((w) => w != '\n' && transcription.contains(w))
        .toList()
      ..sort((a, b) =>
          transcription.indexOf(a).compareTo(transcription.indexOf(b)));

    final spans = <InlineSpan>[];
    int cursor = 0;

    for (final word in positioned) {
      final start = transcription.indexOf(word, cursor);
      if (start == -1) continue;
      if (start > cursor) {
        spans.add(TextSpan(text: transcription.substring(cursor, start)));
      }
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: () => onWordTapped(word),
          child: Container(
            decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: AppColors.primary, width: 2.5)),
            ),
            child: Text(
              word,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 32,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ));
      cursor = start + word.length;
    }
    if (cursor < transcription.length) {
      spans.add(TextSpan(text: transcription.substring(cursor)));
    }

    return Text.rich(
      TextSpan(
        children: spans,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.4),
      ),
      textAlign: TextAlign.center,
    );
  }
}

// ── Watch hint (while video plays) ───────────────────────────────────────────

class _WatchHint extends StatelessWidget {
  final int score;
  const _WatchHint({required this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (score > 0) ...[
          const Icon(Icons.star, color: Color(0xFFFFD700), size: 18),
          const SizedBox(width: 4),
          Text(
            '$score pts',
            style: const TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 20),
        ],
        const Icon(Icons.hearing, color: Colors.white38, size: 18),
        const SizedBox(width: 6),
        const Text(
          'Watch & listen…',
          style: TextStyle(color: Colors.white38, fontSize: 14),
        ),
      ],
    );
  }
}

// ── Quiz panel ────────────────────────────────────────────────────────────────

class _QuizPanel extends StatefulWidget {
  final QuizData quiz;
  final String? selectedAnswer;
  final void Function(bool isCorrect, String answer) onAnswer;

  const _QuizPanel({
    required this.quiz,
    required this.selectedAnswer,
    required this.onAnswer,
  });

  @override
  State<_QuizPanel> createState() => _QuizPanelState();
}

class _QuizPanelState extends State<_QuizPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<Offset> _slide;
  late List<({String text, bool isCorrect})> _options;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _options = [
      (text: widget.quiz.correctAnswer, isCorrect: true),
      (text: widget.quiz.wrongAnswer, isCorrect: false),
    ]..shuffle();
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = ['A', 'B'];

    return SlideTransition(
      position: _slide,
      child: Column(
        children: [
          // Question
          Text(
            widget.quiz.question.isNotEmpty
                ? widget.quiz.question
                : 'What does this sentence mean?',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Answer buttons
          for (var i = 0; i < _options.length; i++) ...[
            _AnswerButton(
              label: labels[i],
              text: _options[i].text,
              isCorrect: _options[i].isCorrect,
              selectedAnswer: widget.selectedAnswer,
              onTap: widget.selectedAnswer == null
                  ? () => widget.onAnswer(
                      _options[i].isCorrect, _options[i].text)
                  : null,
            ),
            if (i < _options.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  final String label;
  final String text;
  final bool isCorrect;
  final String? selectedAnswer;
  final VoidCallback? onTap;

  const _AnswerButton({
    required this.label,
    required this.text,
    required this.isCorrect,
    required this.selectedAnswer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0xFF1E1E2E);
    Color border = Colors.white24;
    Color textColor = Colors.white;

    if (selectedAnswer != null) {
      if (isCorrect) {
        bg = AppColors.correctAnswer.withValues(alpha: 0.25);
        border = AppColors.correctAnswer;
        textColor = AppColors.correctAnswer;
      } else if (selectedAnswer == text) {
        bg = AppColors.wrongAnswer.withValues(alpha: 0.25);
        border = AppColors.wrongAnswer;
        textColor = AppColors.wrongAnswer;
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(label,
                    style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(text,
                    style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
              ),
              if (selectedAnswer != null)
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect
                      ? AppColors.correctAnswer
                      : (selectedAnswer == text
                          ? AppColors.wrongAnswer
                          : Colors.transparent),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Completion panel ──────────────────────────────────────────────────────────

class _CompletionPanel extends StatelessWidget {
  final FeedState feed;
  final VoidCallback onReplay;
  final VoidCallback onNext;

  const _CompletionPanel({
    required this.feed,
    required this.onReplay,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final correct = feed.wasCorrect;

    return Column(
      children: [
        // Result badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: (correct ? AppColors.correctAnswer : AppColors.wrongAnswer)
                .withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: correct ? AppColors.correctAnswer : AppColors.wrongAnswer,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(correct ? Icons.check_circle : Icons.cancel,
                  color: correct
                      ? AppColors.correctAnswer
                      : AppColors.wrongAnswer,
                  size: 20),
              const SizedBox(width: 8),
              Text(
                correct ? '正确！+${100 * feed.combo.clamp(1, 3)} pts' : '加油！Try again',
                style: TextStyle(
                    color: correct
                        ? AppColors.correctAnswer
                        : AppColors.wrongAnswer,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Nav buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReplay,
                icon: const Icon(Icons.replay, size: 18),
                label: const Text('Replay'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: feed.hasNext ? onNext : null,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text(feed.hasNext ? 'Next Clip' : 'Done'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Wide-screen info side panel ───────────────────────────────────────────────

class _InfoSidePanel extends StatelessWidget {
  final VideoSegmentModel segment;

  const _InfoSidePanel({required this.segment});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tap a word to see its definition',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 20),
          const Text('Target Words',
              style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const SizedBox(height: 10),
          if (segment.spokenWords.isEmpty)
            const Text('—', style: TextStyle(color: Colors.white38))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: segment.spokenWords
                  .map((w) => GestureDetector(
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => WordDetailSheet(
                            wordId: w,
                            transcription: segment.transcription,
                            hskLevel: segment.hskLevel,
                          ),
                        ),
                        child: Chip(
                          label: Text(w,
                              style: const TextStyle(fontSize: 18)),
                          backgroundColor: AppColors.primary
                              .withValues(alpha: 0.15),
                          side: const BorderSide(
                              color: AppColors.primary, width: 0.5),
                          labelStyle:
                              const TextStyle(color: AppColors.primary),
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}
