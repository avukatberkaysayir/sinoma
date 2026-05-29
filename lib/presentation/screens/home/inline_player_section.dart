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
  bool _isPlaying = true;
  bool _clipEnded = false;
  // null = choice not made, true = with subtitle, false = without subtitle
  bool? _subtitleChoice;
  bool _quizAnswered = false;
  double _speed = 1.0;
  int _replayCount = 0;
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
    _isPlaying = true;
    _clipEnded = false;
    _subtitleChoice = null;
    _quizAnswered = false;
    _ctrl = null;
    _activeWordId = null;
    _replayCount = 0;
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
      _subtitleChoice = null;
      _quizAnswered = false;
      _replayCount++;   // signals _InlineYoutubePlayerState to reset _ended
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

  void _pickWithSubtitle() => setState(() => _subtitleChoice = true);

  void _pickWithoutSubtitle() {
    setState(() => _subtitleChoice = false);
    Future.delayed(const Duration(milliseconds: 350), _goNext);
  }

  @override
  Widget build(BuildContext context) {
    final seg = _seg;
    final hasQuiz =
        seg.quiz.correctAnswer.isNotEmpty && seg.quiz.wrongAnswer.isNotEmpty;
    final isWide = ResponsiveLayout.isWide(context);

    final playerPanel = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── YouTube player ────────────────────────────────────────────────
          _InlineYoutubePlayer(
            key: ValueKey(seg.videoId),
            segment: seg,
            speed: _speed,
            replayCount: _replayCount,
            onSegmentEnded: _onSegmentEnded,
            onControllerReady: _onControllerReady,
          ),

          // ── Controls bar ──────────────────────────────────────────────────
          _ControlsBar(
            isPlaying: _isPlaying,
            speed: _speed,
            onPrev: _goPrev,
            onReplay: _replay,
            onTogglePlay: _togglePlayPause,
            onNext: _goNext,
            onSpeedChanged: _setSpeed,
          ),

          // ── Post-clip area ────────────────────────────────────────────────
          if (_clipEnded && !_quizAnswered) ...[
            const SizedBox(height: 14),

            // Step 1: VoScreen-style choice (Altyazılı | Altyazısız)
            if (_subtitleChoice == null)
              _SubtitleChoiceButtons(
                onWithSubtitle: _pickWithSubtitle,
                onWithoutSubtitle: _pickWithoutSubtitle,
              ),

            // Step 2: subtitle chosen → Chinese bar + answer buttons
            if (_subtitleChoice == true) ...[
              _ChineseSubtitleBar(transcription: seg.transcription),
              const SizedBox(height: 14),
              if (hasQuiz)
                _AnswerRow(quiz: seg.quiz, onAnswered: _onQuizAnswered)
              else
                _NextButton(onNext: _goNext),
            ],
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
}

// ── Inline YouTube player ─────────────────────────────────────────────────────

class _InlineYoutubePlayer extends StatefulWidget {
  final VideoSegmentModel segment;
  final double speed;
  final int replayCount;
  final VoidCallback onSegmentEnded;
  final void Function(YoutubePlayerController) onControllerReady;

  const _InlineYoutubePlayer({
    super.key,
    required this.segment,
    required this.speed,
    required this.replayCount,
    required this.onSegmentEnded,
    required this.onControllerReady,
  });

  @override
  State<_InlineYoutubePlayer> createState() => _InlineYoutubePlayerState();
}

class _InlineYoutubePlayerState extends State<_InlineYoutubePlayer> {
  late YoutubePlayerController _ctrl;
  Timer? _timer;
  Timer? _overlayTimer;
  StreamSubscription<YoutubePlayerValue>? _stateSub;
  bool _ended = false;
  bool _hasPlayed = false;
  bool _showOverlay = false;
  // Guards against calling playVideo() more than once from the stream listener.
  bool _playAttempted = false;

  @override
  void initState() {
    super.initState();
    _ctrl = YoutubePlayerController.fromVideoId(
      videoId: widget.segment.youtubeId ?? '',
      startSeconds: widget.segment.startTime,
      // autoPlay: false → cueVideoById (load without playing).
      // We trigger play from the stream listener once the player is cued.
      // Starting muted guarantees Chrome allows the play() call — we unMute
      // immediately after the first positive currentTime reading in _tick.
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        mute: true,
        loop: false,
        playsInline: true,
      ),
    );
    widget.onControllerReady(_ctrl);
    _stateSub = _ctrl.stream.listen(_onStateChanged);
    _timer = Timer.periodic(const Duration(milliseconds: 500), _tick);
    _overlayTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted || _hasPlayed || _ended) return;
      setState(() => _showOverlay = true);
    });
  }

  // Called once the YouTube IFrame API signals the video is cued and ready.
  // We intentionally ignore PlayerState.unStarted (-1) because that fires
  // during player initialization before any video is loaded — calling
  // playVideo() there is a no-op that consumes _playAttempted and prevents
  // us from reacting to the real cued (5) event.
  void _onStateChanged(YoutubePlayerValue value) {
    if (_playAttempted) return;
    if (value.playerState == PlayerState.cued) {
      _playAttempted = true;
      _ctrl.playVideo();
    }
  }

  Future<void> _tick(Timer _) async {
    if (_ended) return;
    final t = await _ctrl.currentTime;
    if (t > 0) {
      if (!_hasPlayed) {
        _hasPlayed = true;
        _ctrl.unMute();
        if (_showOverlay && mounted) setState(() => _showOverlay = false);
      }
    }
    if (!_hasPlayed) return;

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
    if (widget.replayCount != old.replayCount) {
      _ended = false;
      _hasPlayed = false;
      _playAttempted = false;
      _overlayTimer?.cancel();
      _showOverlay = false;
      _overlayTimer = Timer(const Duration(milliseconds: 2500), () {
        if (!mounted || _hasPlayed || _ended) return;
        setState(() => _showOverlay = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _overlayTimer?.cancel();
    _stateSub?.cancel();
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
        // Fallback overlay — only appears if autoplay didn't fire within 2.5 s
        if (_showOverlay)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _showOverlay = false);
                _ctrl.playVideo();
              },
              child: Container(
                color: Colors.black38,
                child: const Center(
                  child: _PlayOverlayIcon(),
                ),
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

class _PlayOverlayIcon extends StatelessWidget {
  const _PlayOverlayIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(20),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 52,
      ),
    );
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

// ── Controls bar ──────────────────────────────────────────────────────────────

class _ControlsBar extends StatelessWidget {
  final bool isPlaying;
  final double speed;
  final VoidCallback onPrev;
  final VoidCallback onReplay;
  final VoidCallback onTogglePlay;
  final VoidCallback onNext;
  final void Function(double) onSpeedChanged;

  const _ControlsBar({
    required this.isPlaying,
    required this.speed,
    required this.onPrev,
    required this.onReplay,
    required this.onTogglePlay,
    required this.onNext,
    required this.onSpeedChanged,
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
          child: Icon(icon, color: color ?? AppColors.onSurface, size: size),
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

// ── VoScreen subtitle choice (Altyazılı | Altyazısız) ────────────────────────

class _SubtitleChoiceButtons extends StatelessWidget {
  final VoidCallback onWithSubtitle;
  final VoidCallback onWithoutSubtitle;

  const _SubtitleChoiceButtons({
    required this.onWithSubtitle,
    required this.onWithoutSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.surfaceVariant : Colors.white;
    final border = isDark ? Colors.white24 : Colors.black12;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: _ChoiceBtn(
              label: 'Altyazılı',
              icon: Icons.closed_caption_rounded,
              bg: bg,
              border: border,
              textColor: textColor,
              onTap: onWithSubtitle,
              filled: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ChoiceBtn(
              label: 'Altyazısız',
              icon: Icons.closed_caption_off_outlined,
              bg: bg,
              border: border,
              textColor: textColor,
              onTap: onWithoutSubtitle,
              filled: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final Color border;
  final Color textColor;
  final VoidCallback onTap;
  final bool filled;

  const _ChoiceBtn({
    required this.label,
    required this.icon,
    required this.bg,
    required this.border,
    required this.textColor,
    required this.onTap,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.primary : bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: filled ? AppColors.primary : border, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 20, color: filled ? Colors.white : textColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: filled ? Colors.white : textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chinese subtitle bar (VoScreen style, appears when Altyazılı chosen) ─────

class _ChineseSubtitleBar extends StatelessWidget {
  final String transcription;
  const _ChineseSubtitleBar({required this.transcription});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        transcription,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      ),
    );
  }
}

// ── Answer buttons (correct / wrong, shuffled) ────────────────────────────────

class _AnswerRow extends StatefulWidget {
  final QuizData quiz;
  final VoidCallback onAnswered;

  const _AnswerRow({required this.quiz, required this.onAnswered});

  @override
  State<_AnswerRow> createState() => _AnswerRowState();
}

class _AnswerRowState extends State<_AnswerRow> {
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
    Future.delayed(const Duration(milliseconds: 850), widget.onAnswered);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Row(
        children: _opts
            .map((opt) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _AnswerButton(
                      opt: opt,
                      selected: _selected,
                      onTap: () => _pick(opt),
                    ),
                  ),
                ))
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

class _AnswerButton extends StatelessWidget {
  final _Opt opt;
  final String? selected;
  final VoidCallback onTap;

  const _AnswerButton(
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
      bg = AppColors.correctAnswer.withValues(alpha: 0.15);
      borderColor = AppColors.correctAnswer;
      textColor = AppColors.correctAnswer;
    } else if (selected == opt.text) {
      bg = AppColors.wrongAnswer.withValues(alpha: 0.15);
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
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
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

// ── No-quiz fallback ──────────────────────────────────────────────────────────

class _NextButton extends StatelessWidget {
  final VoidCallback onNext;
  const _NextButton({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: 52,
        child: FilledButton.icon(
          onPressed: onNext,
          icon: const Icon(Icons.skip_next_rounded, size: 20),
          label: const Text('Sonraki Klip',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
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
