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
  bool _subtitleVisible = true;
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
    if (widget.segments != old.segments && widget.segments.isNotEmpty) {
      setState(() {
        _index = Random().nextInt(widget.segments.length);
        _resetState();
      });
    }
  }

  void _resetState() {
    _subtitleVisible = true;
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

          // ── Red-bordered subtitle box (always rendered) ───────────────────
          _SubtitleBox(
            segment: seg,
            visible: _subtitleVisible,
            onWordTapped: isWide
                ? (w) => setState(() => _activeWordId = w)
                : (w) => _showWordSheet(context, w, seg),
          ),

          // ── Controls bar ──────────────────────────────────────────────────
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

          // ── VoScreen-style answer buttons (post-clip) ─────────────────────
          if (_clipEnded && !_quizAnswered) ...[
            const SizedBox(height: 12),
            _VoscreenAnswerRow(
              quiz: hasQuiz ? seg.quiz : null,
              onAnswered: _onQuizAnswered,
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

// ── Red-bordered subtitle box ─────────────────────────────────────────────────

class _SubtitleBox extends StatelessWidget {
  final VideoSegmentModel segment;
  final bool visible;
  final void Function(String) onWordTapped;

  const _SubtitleBox({
    required this.segment,
    required this.visible,
    required this.onWordTapped,
  });

  static const _salmonColor = Color(0xFFFA8072);
  static const _redBorder = Color(0xFFD32F2F);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.35)
            : Colors.white.withValues(alpha: 0.9),
        border: Border.all(color: _redBorder, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: visible
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TappableTranscription(
                  transcription: segment.transcription,
                  targetWords: segment.targetWords,
                  onWordTapped: onWordTapped,
                ),
                const SizedBox(height: 6),
                Text(
                  segment.pinyin,
                  style: const TextStyle(color: _salmonColor, fontSize: 13),
                  textAlign: TextAlign.center,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plainColor = isDark ? Colors.white : Colors.black87;

    if (targetWords.isEmpty) {
      return Text(
        transcription,
        style: TextStyle(color: plainColor, fontSize: 22),
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
        spans.add(_plain(transcription.substring(cursor, start), plainColor));
      }
      spans.add(_highlighted(word));
      cursor = start + word.length;
    }
    if (cursor < transcription.length) {
      spans.add(_plain(transcription.substring(cursor), plainColor));
    }

    return Wrap(alignment: WrapAlignment.center, children: spans);
  }

  Widget _plain(String t, Color color) =>
      Text(t, style: TextStyle(color: color, fontSize: 22));

  Widget _highlighted(String word) => GestureDetector(
        onTap: () => onWordTapped(word),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.yellow.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            word,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
}

// ── Controls bar ──────────────────────────────────────────────────────────────

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
          _CtrlBtn(
              icon: Icons.skip_previous_rounded,
              onTap: onPrev,
              size: 28,
              tooltip: 'Önceki'),
          _CtrlBtn(
              icon: Icons.replay_rounded,
              onTap: onReplay,
              size: 24,
              tooltip: 'Tekrar oynat'),
          _CtrlBtn(
              icon: isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              onTap: onTogglePlay,
              size: 34,
              tooltip: isPlaying ? 'Duraklat' : 'Oynat',
              color: AppColors.primary),
          _CtrlBtn(
              icon: Icons.skip_next_rounded,
              onTap: onNext,
              size: 28,
              tooltip: 'Sonraki'),

          const Spacer(),

          for (final s in _speeds)
            _SpeedChip(
              label: s == 1.0 ? '1×' : '$s×',
              selected: speed == s,
              onTap: () => onSpeedChanged(s),
            ),

          const SizedBox(width: 8),

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

// ── VoScreen-style answer buttons ─────────────────────────────────────────────

class _VoscreenAnswerRow extends StatefulWidget {
  final QuizData? quiz;
  final VoidCallback onAnswered;
  final VoidCallback onNext;

  const _VoscreenAnswerRow({
    required this.quiz,
    required this.onAnswered,
    required this.onNext,
  });

  @override
  State<_VoscreenAnswerRow> createState() => _VoscreenAnswerRowState();
}

class _VoscreenAnswerRowState extends State<_VoscreenAnswerRow> {
  String? _selected;
  late List<_Opt> _opts;

  @override
  void initState() {
    super.initState();
    if (widget.quiz != null) {
      _opts = [
        _Opt(widget.quiz!.correctAnswer, true),
        _Opt(widget.quiz!.wrongAnswer, false),
      ]..shuffle();
    } else {
      _opts = [];
    }
  }

  void _pick(_Opt opt) {
    if (_selected != null) return;
    setState(() => _selected = opt.text);
    Future.delayed(const Duration(milliseconds: 850), widget.onAnswered);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.quiz == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: widget.onNext,
            icon: const Icon(Icons.skip_next_rounded, size: 20),
            label: const Text('Sonraki Klip',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: _opts
            .map(
              (opt) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _VoscreenButton(
                    opt: opt,
                    selected: _selected,
                    onTap: () => _pick(opt),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Opt {
  final String text;
  final bool correct;
  const _Opt(this.text, this.correct);
}

class _VoscreenButton extends StatelessWidget {
  final _Opt opt;
  final String? selected;
  final VoidCallback onTap;

  const _VoscreenButton(
      {required this.opt, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final revealed = selected != null;
    Color bg;
    Color borderColor;
    Color textColor;

    if (!revealed) {
      bg = AppColors.surfaceVariant;
      borderColor = AppColors.onSurfaceMuted;
      textColor = AppColors.onSurface;
    } else if (opt.correct) {
      bg = AppColors.correctAnswer.withValues(alpha: 0.18);
      borderColor = AppColors.correctAnswer;
      textColor = AppColors.correctAnswer;
    } else if (selected == opt.text) {
      bg = AppColors.wrongAnswer.withValues(alpha: 0.18);
      borderColor = AppColors.wrongAnswer;
      textColor = AppColors.wrongAnswer;
    } else {
      bg = AppColors.surfaceVariant;
      borderColor = AppColors.onSurfaceMuted;
      textColor = AppColors.onSurfaceMuted;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: InkWell(
        onTap: revealed ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Text(
            opt.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
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
