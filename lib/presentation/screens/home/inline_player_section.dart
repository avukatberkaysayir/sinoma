import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/video_segment_model.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../widgets/common/word_detail_sheet.dart';

// ── Public entry point ────────────────────────────────────────────────────────

class InlinePlayerSection extends StatefulWidget {
  final List<VideoSegmentModel> segments;

  const InlinePlayerSection({super.key, required this.segments});

  @override
  State<InlinePlayerSection> createState() => _InlinePlayerSectionState();
}

class _InlinePlayerSectionState extends State<InlinePlayerSection> {
  late int _index;
  bool _subtitleVisible = false;
  bool _isPlaying = true;
  bool _clipEnded = false;
  bool _quizAnswered = false;
  double _speed = 1.0;
  YoutubePlayerController? _ctrl;
  String? _activeWordId;

  @override
  void initState() {
    super.initState();
    _index = Random().nextInt(widget.segments.length);
  }

  @override
  void didUpdateWidget(InlinePlayerSection old) {
    super.didUpdateWidget(old);
    // Filters changed → pick new random video
    if (widget.segments != old.segments && widget.segments.isNotEmpty) {
      setState(() {
        _index = Random().nextInt(widget.segments.length);
        _resetState();
      });
    }
  }

  void _resetState() {
    _subtitleVisible = false;
    _isPlaying = true;
    _clipEnded = false;
    _quizAnswered = false;
    _ctrl = null;
    _activeWordId = null;
  }

  VideoSegmentModel get _seg => widget.segments[_index];

  void _onControllerReady(YoutubePlayerController ctrl) => _ctrl = ctrl;

  void _onSegmentEnded() {
    setState(() {
      _isPlaying = false;
      _clipEnded = true;
    });
  }

  void _goNext() {
    if (!mounted) return;
    setState(() {
      _index = (_index + 1) % widget.segments.length;
      _resetState();
    });
  }

  void _goPrev() {
    if (!mounted) return;
    setState(() {
      _index = (_index - 1 + widget.segments.length) % widget.segments.length;
      _resetState();
    });
  }

  void _replay() {
    _ctrl?.seekTo(seconds: _seg.startTime, allowSeekAhead: true);
    _ctrl?.playVideo();
    setState(() {
      _isPlaying = true;
      _clipEnded = false;
      _subtitleVisible = false;
      _quizAnswered = false;
    });
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _ctrl?.pauseVideo();
    } else {
      _ctrl?.playVideo();
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  void _setSpeed(double speed) {
    _ctrl?.setPlaybackRate(speed);
    setState(() => _speed = speed);
  }

  void _onQuizAnswered() {
    setState(() => _quizAnswered = true);
    Future.delayed(const Duration(milliseconds: 900), _goNext);
  }

  @override
  Widget build(BuildContext context) {
    final seg = _seg;
    final hasQuiz = seg.quiz.correctAnswer.isNotEmpty &&
        seg.quiz.wrongAnswer.isNotEmpty;
    final isWide = ResponsiveLayout.isWide(context);

    final playerPanel = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── YouTube IFrame player ─────────────────────────────────────────
          _InlineYoutubePlayer(
            key: ValueKey(seg.videoId),
            segment: seg,
            speed: _speed,
            onSegmentEnded: _onSegmentEnded,
            onControllerReady: _onControllerReady,
          ),

          // ── Subtitle reveal (VoScreen style) ─────────────────────────────
          _SubtitleReveal(
            segment: seg,
            visible: _subtitleVisible,
            onWordTapped: isWide
                ? (w) => setState(() => _activeWordId = w)
                : (w) => _showWordSheet(context, w, seg),
          ),

          // ── Controls bar (YouGlish style) ─────────────────────────────────
          _ControlsBar(
            isPlaying: _isPlaying,
            speed: _speed,
            subtitleVisible: _subtitleVisible,
            onPrev: _goPrev,
            onReplay: _replay,
            onTogglePlay: _togglePlayPause,
            onNext: _goNext,
            onSpeedChanged: _setSpeed,
            onToggleSubtitle: () =>
                setState(() => _subtitleVisible = !_subtitleVisible),
          ),

          // ── Post-clip area: quiz OR subtitle toggle ───────────────────────
          if (_clipEnded && !_quizAnswered) ...[
            const SizedBox(height: 12),
            if (hasQuiz)
              _InlineQuiz(quiz: seg.quiz, onAnswered: _onQuizAnswered)
            else
              _SubtitleChoiceRow(
                subtitleVisible: _subtitleVisible,
                onShowSubtitle: () => setState(() => _subtitleVisible = true),
                onHideSubtitle: () => setState(() => _subtitleVisible = false),
                onNext: _goNext,
              ),
          ],

          if (_quizAnswered)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle,
                      color: AppColors.correctAnswer, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Sonraki klibe geçiliyor…',
                    style: TextStyle(color: AppColors.correctAnswer),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );

    if (!isWide) return playerPanel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: playerPanel),
        Expanded(
          flex: 2,
          child: Container(
            color: AppColors.surfaceVariant,
            height: double.infinity,
            child: _activeWordId != null
                ? _SideWordDetail(
                    wordId: _activeWordId!,
                    transcription: seg.transcription,
                    hskLevel: seg.hskLevel,
                    onClose: () => setState(() => _activeWordId = null),
                  )
                : const Center(
                    child: Text(
                      'Kelimeye dokun → tanım',
                      style: TextStyle(
                          color: AppColors.onSurfaceMuted, fontSize: 14),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _showWordSheet(
      BuildContext ctx, String wordId, VideoSegmentModel seg) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WordDetailSheet(
        wordId: wordId,
        transcription: seg.transcription,
        hskLevel: seg.hskLevel,
      ),
    );
  }
}

// ── Inline YouTube player with controller exposure ────────────────────────────

class _InlineYoutubePlayer extends StatefulWidget {
  final VideoSegmentModel segment;
  final double speed;
  final VoidCallback onSegmentEnded;
  final void Function(YoutubePlayerController) onControllerReady;

  const _InlineYoutubePlayer({
    super.key,
    required this.segment,
    required this.speed,
    required this.onSegmentEnded,
    required this.onControllerReady,
  });

  @override
  State<_InlineYoutubePlayer> createState() => _InlineYoutubePlayerState();
}

class _InlineYoutubePlayerState extends State<_InlineYoutubePlayer> {
  late YoutubePlayerController _ctrl;
  Timer? _timer;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _ctrl = YoutubePlayerController.fromVideoId(
      videoId: widget.segment.youtubeId ?? '',
      startSeconds: widget.segment.startTime,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        mute: false,
        loop: false,
        playsInline: true,
      ),
    );
    widget.onControllerReady(_ctrl);
    _timer = Timer.periodic(const Duration(milliseconds: 500), _tick);
  }

  Future<void> _tick(Timer _) async {
    if (_ended) return;
    final t = await _ctrl.currentTime;
    if (t >= widget.segment.endTime) {
      _ended = true;
      await _ctrl.pauseVideo();
      widget.onSegmentEnded();
    } else if (t < widget.segment.startTime - 1) {
      await _ctrl.seekTo(
          seconds: widget.segment.startTime, allowSeekAhead: true);
    }
  }

  @override
  void didUpdateWidget(_InlineYoutubePlayer old) {
    super.didUpdateWidget(old);
    if (widget.speed != old.speed) {
      _ctrl.setPlaybackRate(widget.speed);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: YoutubePlayer(controller: _ctrl),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: _HskBadge(level: widget.segment.hskLevel),
        ),
        Positioned(
          bottom: 8,
          left: 8,
          child: Text(
            '${widget.segment.hskLevel >= 1 ? widget.segment.quizCategory.emoji : ''} '
            '${_fmtTime(widget.segment.startTime)}–${_fmtTime(widget.segment.endTime)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              shadows: [Shadow(blurRadius: 4)],
            ),
          ),
        ),
      ],
    );
  }

  String _fmtTime(double s) {
    final m = s ~/ 60;
    final sec = (s % 60).toInt();
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

class _HskBadge extends StatelessWidget {
  final int level;
  const _HskBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.forHskLevel(level),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'HSK $level',
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ── Subtitle reveal panel (VoScreen style) ────────────────────────────────────

class _SubtitleReveal extends StatelessWidget {
  final VideoSegmentModel segment;
  final bool visible;
  final void Function(String) onWordTapped;

  const _SubtitleReveal({
    required this.segment,
    required this.visible,
    required this.onWordTapped,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      color: AppColors.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: visible
          ? Column(
              children: [
                Text(
                  segment.pinyin,
                  style: const TextStyle(
                      color: AppColors.onSurfaceMuted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                _TappableTranscription(
                  transcription: segment.transcription,
                  targetWords: segment.targetWords,
                  onWordTapped: onWordTapped,
                ),
              ],
            )
          : const SizedBox(
              height: 24,
              child: Center(
                child: Text(
                  '• • •',
                  style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 16),
                ),
              ),
            ),
    );
  }
}

class _TappableTranscription extends StatelessWidget {
  final String transcription;
  final List<String> targetWords;
  final void Function(String) onWordTapped;

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
        style: const TextStyle(color: AppColors.onSurface, fontSize: 22),
        textAlign: TextAlign.center,
      );
    }
    final positioned = targetWords
        .where(transcription.contains)
        .toList()
      ..sort((a, b) =>
          transcription.indexOf(a).compareTo(transcription.indexOf(b)));

    final spans = <Widget>[];
    int cursor = 0;
    for (final word in positioned) {
      final start = transcription.indexOf(word, cursor);
      if (start == -1) continue;
      if (start > cursor) {
        spans.add(_plain(transcription.substring(cursor, start)));
      }
      spans.add(_tappable(word));
      cursor = start + word.length;
    }
    if (cursor < transcription.length) {
      spans.add(_plain(transcription.substring(cursor)));
    }

    return Wrap(alignment: WrapAlignment.center, children: spans);
  }

  Widget _plain(String t) =>
      Text(t, style: const TextStyle(color: AppColors.onSurface, fontSize: 22));

  Widget _tappable(String word) => GestureDetector(
        onTap: () => onWordTapped(word),
        child: Container(
          decoration: const BoxDecoration(
            border:
                Border(bottom: BorderSide(color: AppColors.primary, width: 2)),
          ),
          child: Text(
            word,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
}

// ── YouGlish-style controls bar ───────────────────────────────────────────────

class _ControlsBar extends StatelessWidget {
  final bool isPlaying;
  final double speed;
  final bool subtitleVisible;
  final VoidCallback onPrev;
  final VoidCallback onReplay;
  final VoidCallback onTogglePlay;
  final VoidCallback onNext;
  final void Function(double) onSpeedChanged;
  final VoidCallback onToggleSubtitle;

  const _ControlsBar({
    required this.isPlaying,
    required this.speed,
    required this.subtitleVisible,
    required this.onPrev,
    required this.onReplay,
    required this.onTogglePlay,
    required this.onNext,
    required this.onSpeedChanged,
    required this.onToggleSubtitle,
  });

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // ← prev
          _CtrlBtn(
              icon: Icons.skip_previous_rounded,
              onTap: onPrev,
              size: 28,
              tooltip: 'Önceki'),
          // ↺ replay
          _CtrlBtn(
              icon: Icons.replay_rounded,
              onTap: onReplay,
              size: 24,
              tooltip: 'Tekrar oynat'),
          // ⏸ / ▶
          _CtrlBtn(
              icon: isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              onTap: onTogglePlay,
              size: 34,
              tooltip: isPlaying ? 'Duraklat' : 'Oynat',
              color: AppColors.primary),
          // → next
          _CtrlBtn(
              icon: Icons.skip_next_rounded,
              onTap: onNext,
              size: 28,
              tooltip: 'Sonraki'),

          const Spacer(),

          // Speed chips
          for (final s in _speeds)
            _SpeedChip(
              label: s == 1.0 ? '1×' : '$s×',
              selected: speed == s,
              onTap: () => onSpeedChanged(s),
            ),

          const SizedBox(width: 8),

          // CC toggle
          _CtrlBtn(
            icon: subtitleVisible
                ? Icons.closed_caption_rounded
                : Icons.closed_caption_off_outlined,
            onTap: onToggleSubtitle,
            size: 22,
            tooltip: subtitleVisible ? 'Altyazıyı gizle' : 'Altyazıyı göster',
            color:
                subtitleVisible ? AppColors.primary : AppColors.onSurfaceMuted,
          ),
        ],
      ),
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final String tooltip;
  final Color? color;

  const _CtrlBtn({
    required this.icon,
    required this.onTap,
    required this.size,
    required this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Icon(icon,
              color: color ?? AppColors.onSurface,
              size: size),
        ),
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SpeedChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.onSurfaceMuted,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.onSurfaceMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Post-clip: subtitle choice (VoScreen style) ───────────────────────────────

class _SubtitleChoiceRow extends StatelessWidget {
  final bool subtitleVisible;
  final VoidCallback onShowSubtitle;
  final VoidCallback onHideSubtitle;
  final VoidCallback onNext;

  const _SubtitleChoiceRow({
    required this.subtitleVisible,
    required this.onShowSubtitle,
    required this.onHideSubtitle,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: subtitleVisible ? onHideSubtitle : onShowSubtitle,
              icon: Icon(
                subtitleVisible
                    ? Icons.closed_caption_off_outlined
                    : Icons.closed_caption_rounded,
                size: 18,
              ),
              label: Text(subtitleVisible ? 'Altyazıyı Gizle' : 'Altyazıyı Göster'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.onSurface,
                side: const BorderSide(color: AppColors.onSurfaceMuted),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.skip_next_rounded, size: 18),
              label: const Text('Sonraki Klip'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inline quiz (for videos with real quiz data) ──────────────────────────────

class _InlineQuiz extends StatefulWidget {
  final QuizData quiz;
  final VoidCallback onAnswered;

  const _InlineQuiz({required this.quiz, required this.onAnswered});

  @override
  State<_InlineQuiz> createState() => _InlineQuizState();
}

class _InlineQuizState extends State<_InlineQuiz> {
  String? _selected;
  late List<_Opt> _opts;

  @override
  void initState() {
    super.initState();
    _opts = [
      _Opt(widget.quiz.correctAnswer, true),
      _Opt(widget.quiz.wrongAnswer, false),
    ]..shuffle();
  }

  void _pick(_Opt opt) {
    if (_selected != null) return;
    setState(() => _selected = opt.text);
    Future.delayed(const Duration(milliseconds: 800), widget.onAnswered);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.quiz.question.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                widget.quiz.question,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Row(
            children: _opts
                .map(
                  (opt) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _QuizButton(
                        opt: opt,
                        selected: _selected,
                        onTap: () => _pick(opt),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _Opt {
  final String text;
  final bool correct;
  const _Opt(this.text, this.correct);
}

class _QuizButton extends StatelessWidget {
  final _Opt opt;
  final String? selected;
  final VoidCallback onTap;

  const _QuizButton(
      {required this.opt, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color bg = AppColors.surfaceVariant;
    if (selected != null) {
      if (opt.correct) bg = AppColors.correctAnswer;
      if (!opt.correct && selected == opt.text) bg = AppColors.wrongAnswer;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.onSurfaceMuted),
      ),
      child: InkWell(
        onTap: selected == null ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          child: Text(
            opt.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Side word detail panel (wide screen) ─────────────────────────────────────

class _SideWordDetail extends StatelessWidget {
  final String wordId;
  final String transcription;
  final int hskLevel;
  final VoidCallback onClose;

  const _SideWordDetail({
    required this.wordId,
    required this.transcription,
    required this.hskLevel,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Kelime Detayı',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.onSurfaceMuted),
                onPressed: onClose,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.surface),
        Expanded(
          child: SingleChildScrollView(
            child: WordDetailSheet(
              wordId: wordId,
              transcription: transcription,
              hskLevel: hskLevel,
            ),
          ),
        ),
      ],
    );
  }
}
