import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/video_segment_model.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../providers/locale_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common/word_detail_sheet.dart';
import '../../widgets/video/direct_youtube_player.dart';

// ── Public entry point ────────────────────────────────────────────────────────

class InlinePlayerSection extends ConsumerStatefulWidget {
  final List<VideoSegmentModel> segments;

  const InlinePlayerSection({super.key, required this.segments});

  @override
  ConsumerState<InlinePlayerSection> createState() =>
      _InlinePlayerSectionState();
}

class _InlinePlayerSectionState extends ConsumerState<InlinePlayerSection> {
  late int _index;
  bool _clipEnded = false;
  bool? _subtitleChoice;
  String? _pickedAnswer; // option text the user picked — frozen, survives replay
  bool _optSwap = false; // stable left/right order for the two options
  double _speed = 1.0;
  int _replayCount = 0;
  bool _soundOn = false;
  final DirectYouTubeController _playerCtrl = DirectYouTubeController();
  String? _activeWordId;

  // Choice countdown — starts when the segment ends, keeps running through
  // replays, stops on a choice; on timeout it's a miss → advance (penalty).
  static const int _choiceSeconds = 20;
  Timer? _countdownTimer;
  int _countdown = _choiceSeconds;
  bool _countdownActive = false;
  bool _timedOut = false; // choice window expired without a selection

  @override
  void initState() {
    super.initState();
    _index = Random().nextInt(widget.segments.length);
    _optSwap = Random().nextBool();
  }

  @override
  void didUpdateWidget(InlinePlayerSection old) {
    super.didUpdateWidget(old);
    if (widget.segments != old.segments && widget.segments.isNotEmpty) {
      // Keep showing the current clip if it still exists in the new list (the
      // feed can re-emit for unrelated reasons); only jump when it's gone.
      final currentId = (old.segments.isNotEmpty && _index < old.segments.length)
          ? old.segments[_index].videoId
          : null;
      final keep =
          widget.segments.indexWhere((s) => s.videoId == currentId);
      setState(() {
        if (keep >= 0) {
          _index = keep;
        } else {
          _index = Random().nextInt(widget.segments.length);
          _resetState();
        }
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _resetState() {
    _clipEnded = false;
    _subtitleChoice = null;
    _pickedAnswer = null;
    _optSwap = Random().nextBool();
    _timedOut = false;
    _activeWordId = null;
    _replayCount = 0;
    _stopCountdown();
    _countdown = _choiceSeconds;
  }

  // ── Scoring ────────────────────────────────────────────────────────────────
  // Correct = (word count) × (HSK level) × 2  →  6 HSK-1 words = 12.
  // Penalty = (HSK level) × 2  (level = highest word level in the segment).

  int _correctPoints(VideoSegmentModel seg) {
    final words = seg.targetWords.isEmpty ? 1 : seg.targetWords.length;
    final level = seg.hskLevel <= 0 ? 1 : seg.hskLevel;
    return words * level * 2;
  }

  int _penaltyPoints(VideoSegmentModel seg) {
    final level = seg.hskLevel <= 0 ? 1 : seg.hskLevel;
    return level * 2;
  }

  void _addScore(int delta, {bool answered = true}) {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    final newStats = user.stats.copyWith(
      totalScore: (user.stats.totalScore + delta).clamp(0, 1 << 30),
      questionsAnswered:
          user.stats.questionsAnswered + (answered ? 1 : 0),
    );
    ref.read(userRepositoryProvider).updateUserStats(user.uid, newStats);
  }

  VideoSegmentModel get _seg => widget.segments[_index];

  void _onSegmentEnded() {
    setState(() => _clipEnded = true);
    // Start the choice countdown the first time the segment ends. Guarded so a
    // replay (which ends again) does not restart it.
    if (_subtitleChoice == null) _startCountdown();
  }

  void _startCountdown() {
    if (_countdownActive) return;
    _countdownActive = true;
    _countdown = _choiceSeconds;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        // Missed the choice window → penalty. Don't auto-advance; the next
        // arrow appears and the user taps it to continue.
        final delta = -_penaltyPoints(_seg);
        _addScore(delta, answered: false);
        _playerCtrl.showScorePopup(delta);
        setState(() {
          _countdownActive = false;
          _timedOut = true;
        });
      }
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownActive = false;
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
    // Re-listen only: replay the clip while the post-clip UI (subtitle choice,
    // options, picked answer) stays put — nothing below changes.
    setState(() => _replayCount++);
  }

  void _setSpeed(double speed) {
    _playerCtrl.setPlaybackRate(speed);
    setState(() => _speed = speed);
  }

  String _fmtTime(double s) {
    final m = s ~/ 60;
    final sec = (s % 60).toInt();
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  void _onPick(String text, bool correct) {
    if (_pickedAnswer != null || _timedOut) return; // one answer only; none after timeout
    _stopCountdown();
    final seg = _seg;
    final delta = correct ? _correctPoints(seg) : -_penaltyPoints(seg);
    _addScore(delta);
    _playerCtrl.showScorePopup(delta);
    // No auto-advance — the player shows a "next" arrow; the user taps it.
    setState(() => _pickedAnswer = text);
  }

  // Choosing subtitled/unsubtitled does NOT stop the countdown — it keeps
  // running as the answer window and stops only when an option is picked.
  void _pickWithSubtitle() {
    setState(() => _subtitleChoice = true);
  }

  void _pickWithoutSubtitle() {
    setState(() => _subtitleChoice = false);
  }

  // Transparent CC toggle over the options — show/hide the subtitle anytime.
  void _toggleSubtitle() {
    setState(() => _subtitleChoice = !(_subtitleChoice ?? false));
  }

  @override
  Widget build(BuildContext context) {
    final seg = _seg;
    final lang = ref.watch(localeProvider).languageCode;
    final l10n = AppL10n.fromCode(lang);
    final quizCorrect = seg.quiz.correctFor(lang);
    final quizWrong = seg.quiz.wrongFor(lang);
    final hasQuiz = quizCorrect.isNotEmpty && quizWrong.isNotEmpty;
    final isWide = ResponsiveLayout.isWide(context);

    final playerPanel = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── YouTube player ────────────────────────────────────────────────
          Stack(
            children: [
              DirectYouTubePlayer(
                key: ValueKey('${seg.videoId}-${seg.startTime}'),
                videoId: seg.youtubeId ?? '',
                startTime: seg.startTime,
                endTime: seg.endTime,
                hskLevel: seg.hskLevel,
                replayCount: _replayCount,
                controller: _playerCtrl,
                onSegmentEnded: _onSegmentEnded,
                onSoundChanged: (v) {
                  if (mounted) setState(() => _soundOn = v);
                },
                countdown: _countdown,
                showCountdown: _countdownActive,
                showReplay: _clipEnded,
                showNext: _subtitleChoice != null || _timedOut,
                onReplayTap: _replay,
                onNextTap: _goNext,
              ),
              Positioned(
                top: 8,
                left: 8,
                child: _HskBadge(level: seg.hskLevel),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Text(
                  '${seg.hskLevel >= 1 ? seg.quizCategory.emoji : ''} '
                  '${_fmtTime(seg.startTime)}–${_fmtTime(seg.endTime)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    shadows: [Shadow(blurRadius: 4)],
                  ),
                ),
              ),
            ],
          ),

          // ── Controls bar ──────────────────────────────────────────────────
          _ControlsBar(
            speed: _speed,
            soundOn: _soundOn,
            onToggleSound: _playerCtrl.toggleSound,
            onPrev: _goPrev,
            onReplay: _replay,
            onSpeedChanged: _setSpeed,
          ),

          // ── Post-clip area ────────────────────────────────────────────────
          if (_clipEnded) ...[
            const SizedBox(height: 14),

            // Step 1: choice (Subtitles On | Subtitles Off) — only while the
            // choice window is open (not after a pick or timeout).
            if (_subtitleChoice == null && !_timedOut)
              _SubtitleChoiceButtons(
                onLabel: l10n.subtitlesOn,
                offLabel: l10n.subtitlesOff,
                onWithSubtitle: _pickWithSubtitle,
                onWithoutSubtitle: _pickWithoutSubtitle,
              ),

            // Step 2: after a choice → the two answer options always show; the
            // Chinese subtitle bar shows only when subtitles are toggled on.
            // A transparent CC toggle floats over the options so the user can
            // show/hide the subtitle at any time, regardless of the first pick.
            // Options freeze after one pick; advance via the player's next arrow.
            if (_subtitleChoice != null) ...[
              // Subtitle OFF → show the transparent "Subtitle" toggle (tap to
              // reveal). Subtitle ON → the button is gone and the subtitle bar
              // takes its place (tap the bar to hide it again). Locale-aware.
              if (_subtitleChoice != true) ...[
                Center(
                  child: _SubtitleToggle(
                    on: false,
                    label: l10n.subtitleTitle,
                    onTap: _toggleSubtitle,
                  ),
                ),
                const SizedBox(height: 10),
              ] else ...[
                GestureDetector(
                  onTap: _toggleSubtitle,
                  child: _ChineseSubtitleBar(
                    transcription: seg.targetWords.isNotEmpty
                        ? seg.targetWords.join('')
                        : seg.transcription,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (hasQuiz)
                _AnswerRow(
                  correct: quizCorrect,
                  wrong: quizWrong,
                  swap: _optSwap,
                  selected: _pickedAnswer,
                  // Freeze (reveal correct, ignore taps) once answered
                  // OR after the countdown expired without an answer.
                  revealed: _pickedAnswer != null || _timedOut,
                  onPick: _onPick,
                ),
            ],
          ],

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
  final double speed;
  final bool soundOn;
  final VoidCallback onToggleSound;
  final VoidCallback onPrev;
  final VoidCallback onReplay;
  final void Function(double) onSpeedChanged;

  const _ControlsBar({
    required this.speed,
    required this.soundOn,
    required this.onToggleSound,
    required this.onPrev,
    required this.onReplay,
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

          // Sound toggle — same plain pattern as the play button (no builder).
          _CtrlBtn(
            icon: soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            onTap: onToggleSound,
            size: 26,
            tooltip: soundOn ? 'Sesi kapat' : 'Sesi aç',
            color: soundOn ? null : AppColors.primary,
          ),

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
  final String onLabel;
  final String offLabel;
  final VoidCallback onWithSubtitle;
  final VoidCallback onWithoutSubtitle;

  const _SubtitleChoiceButtons({
    required this.onLabel,
    required this.offLabel,
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
              label: onLabel,
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
              label: offLabel,
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

// ── Transparent subtitle toggle (floats over the options) ────────────────────

class _SubtitleToggle extends StatelessWidget {
  final bool on;
  final String label;
  final VoidCallback onTap;
  const _SubtitleToggle(
      {required this.on, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = on ? AppColors.primary : AppColors.onSurfaceMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                on
                    ? Icons.closed_caption_rounded
                    : Icons.closed_caption_off_outlined,
                size: 16,
                color: accent,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                    color: accent, fontSize: 12, fontWeight: FontWeight.w600),
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

// Stateless and parent-driven: the picked answer and the left/right order live
// in the parent so the selection stays frozen across replays (which rebuild
// this widget). Once [selected] is non-null, taps are ignored.
class _AnswerRow extends StatelessWidget {
  final String correct;
  final String wrong;
  final bool swap;
  final String? selected;
  final bool revealed;
  final void Function(String text, bool correct) onPick;

  const _AnswerRow({
    required this.correct,
    required this.wrong,
    required this.swap,
    required this.selected,
    required this.revealed,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final opts = swap
        ? [_Opt(wrong, false), _Opt(correct, true)]
        : [_Opt(correct, true), _Opt(wrong, false)];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Row(
        children: opts
            .map((opt) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _AnswerButton(
                      opt: opt,
                      selected: selected,
                      revealed: revealed,
                      onTap: revealed
                          ? null
                          : () => onPick(opt.text, opt.correct),
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
  final bool revealed;
  final VoidCallback? onTap;

  const _AnswerButton(
      {required this.opt,
      required this.selected,
      required this.revealed,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
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
