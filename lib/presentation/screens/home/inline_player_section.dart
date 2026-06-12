import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/web_sfx.dart';
import '../../../data/models/dictionary_model.dart';
import '../../../data/models/video_segment_model.dart';
import '../../../data/repositories/video_repository.dart';
import '../../providers/dictionary_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/video_provider.dart';
import '../../widgets/video/direct_youtube_player.dart';

// The player's subtitle + answer options keep a familiar handwritten face
// (site-wide ZCOOL XiaoWei stays everywhere else).
const _kComic = 'Comic Sans MS';

// ── Public entry point ────────────────────────────────────────────────────────

class InlinePlayerSection extends ConsumerStatefulWidget {
  final List<VideoSegmentModel> segments;

  // Phase mode (learning path): play [segments] in order from the first; after
  // the last answer call [onPhaseComplete] with how many were answered
  // correctly. Defaults keep the free-feed behaviour (random start, looping).
  final bool phaseMode;
  final void Function(int correct, int total)? onPhaseComplete;
  final void Function(int index)? onIndexChanged; // phase progress
  final void Function(bool correct)? onAnswered; // each answer (for hearts)

  const InlinePlayerSection({
    super.key,
    required this.segments,
    this.phaseMode = false,
    this.onPhaseComplete,
    this.onIndexChanged,
    this.onAnswered,
  });

  @override
  ConsumerState<InlinePlayerSection> createState() =>
      _InlinePlayerSectionState();
}

class _InlinePlayerSectionState extends ConsumerState<InlinePlayerSection> {
  late int _index;
  bool _clipEnded = false;
  bool _replaying = false; // clip is currently re-playing → hide the replay button
  bool? _subtitleChoice;
  String? _pickedAnswer; // option text the user picked — frozen, survives replay
  bool _optSwap = false; // stable left/right order for the two options
  double _speed = 1.0;
  int _replayCount = 0;
  late final VideoRepository _videoRepo; // dispose-safe (see initState)
  bool _soundOn = false;
  final DirectYouTubeController _playerCtrl = DirectYouTubeController();

  // Choice countdown — starts when the segment ends, keeps running through
  // replays, stops on a choice; on timeout it's a miss → advance (penalty).
  static const int _choiceSeconds = 20;
  Timer? _countdownTimer;
  int _countdown = _choiceSeconds;
  bool _countdownActive = false;
  bool _timedOut = false; // choice window expired without a selection
  int _correctCount = 0; // phase mode: correct answers so far
  // VoScreen-style mastery ticks for the CURRENT clip (practice tab only):
  // +1 per correct answer, -1 per wrong/timeout, 0..5, persisted per user.
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    // Cached: onWatched can fire from the player's dispose, when reading a
    // provider through ref would throw (and abort the iframe cleanup).
    _videoRepo = ref.read(videoRepositoryProvider);
    _index = widget.phaseMode ? 0 : Random().nextInt(widget.segments.length);
    _optSwap = Random().nextBool();
    if (widget.phaseMode) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => widget.onIndexChanged?.call(0));
    }
    _loadTicks();
  }

  Future<void> _loadTicks() async {
    if (widget.phaseMode || widget.segments.isEmpty) return;
    final id = _seg.videoId;
    final t = await ref.read(videoRepositoryProvider).loadVideoTicks(id);
    if (mounted && _seg.videoId == id && t != _ticks) {
      setState(() => _ticks = t);
    }
  }

  void _updateTicks(bool correct) {
    if (widget.phaseMode) return;
    final next = (correct ? _ticks + 1 : _ticks - 1).clamp(0, 5);
    if (next == _ticks) return;
    setState(() => _ticks = next);
    ref.read(videoRepositoryProvider).saveVideoTicks(_seg.videoId, next);
  }

  @override
  void didUpdateWidget(InlinePlayerSection old) {
    super.didUpdateWidget(old);
    if (widget.phaseMode) return; // fixed ordered list — no random reindex
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
      _loadTicks();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _resetState() {
    _clipEnded = false;
    _replaying = false;
    _subtitleChoice = null;
    _pickedAnswer = null;
    _optSwap = Random().nextBool();
    _timedOut = false;
    _replayCount = 0;
    _panel = null;
    _stopCountdown();
    _countdown = _choiceSeconds;
  }

  // ── Scoring ────────────────────────────────────────────────────────────────
  // Correct = (word count) × (HSK level) × 2  →  6 HSK-1 words = 12.
  // Penalty = (HSK level) × 2  (level = highest word level in the segment).

  int _correctPoints(VideoSegmentModel seg) {
    final words = seg.spokenWords.isEmpty ? 1 : seg.spokenWords.length;
    final level = seg.hskLevel <= 0 ? 1 : seg.hskLevel;
    return words * level * 2;
  }

  int _penaltyPoints(VideoSegmentModel seg) {
    final level = seg.hskLevel <= 0 ? 1 : seg.hskLevel;
    return level * 2;
  }

  void _addScore(int delta, {bool answered = true}) {
    // The user stream flips to "loading" on every re-emit/invalidation; the
    // stable provider keeps the last user so a timeout penalty (or any score)
    // is never silently dropped in that window.
    final user = ref.read(currentUserProvider).valueOrNull ??
        ref.read(stableCurrentUserProvider);
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
    // Clip stopped → show the replay button again (it's hidden while replaying).
    setState(() {
      _clipEnded = true;
      _replaying = false;
    });
    // Start the choice countdown the first time the segment ends. Guarded so a
    // replay (which ends again) does not restart it, and not after a timeout.
    if (_subtitleChoice == null && !_timedOut) _startCountdown();
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
        // Missed the choice window → the correct option gets revealed, but
        // it counts (and SOUNDS) as a miss: a distinct low timeout buzz, so
        // the reveal can never be mistaken for a correct answer.
        final delta = -_penaltyPoints(_seg);
        WebSfx.timeout();
        _addScore(delta, answered: false);
        _playerCtrl.showScorePopup(delta);
        widget.onAnswered?.call(false); // timeout counts as a wrong answer (heart)
        _updateTicks(false);
        ref.read(videoRepositoryProvider).bumpAnswerStat(false);
        ref.invalidate(dailyAnswerStatsProvider); // daily quests progress
        setState(() {
          _countdownActive = false;
          _timedOut = true;
          // Old (wanted) behaviour: nothing disappears on timeout — the
          // subtitle opens and the options stay, with the correct one
          // revealed. Without this the options block (gated on a subtitle
          // choice) vanished entirely.
          _subtitleChoice ??= true;
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
    if (widget.phaseMode) {
      if (_index >= widget.segments.length - 1) {
        widget.onPhaseComplete?.call(_correctCount, widget.segments.length);
        return;
      }
      setState(() {
        _index += 1;
        _resetState();
      });
      widget.onIndexChanged?.call(_index);
      return;
    }
    setState(() {
      _index = (_index + 1) % widget.segments.length;
      _resetState();
    });
    _loadTicks();
  }

  void _goPrev() {
    if (!mounted) return;
    setState(() {
      _index = (_index - 1 + widget.segments.length) % widget.segments.length;
      _resetState();
    });
    _loadTicks();
  }

  void _replay() {
    // Re-listen only: replay the clip while the post-clip UI (subtitle choice,
    // options, picked answer) stays put — nothing below changes. The replay
    // button hides during playback and returns when the clip ends.
    setState(() {
      _replaying = true;
      _replayCount++;
    });
  }

  void _setSpeed(double speed) {
    _playerCtrl.setPlaybackRate(speed);
    setState(() => _speed = speed);
  }

  String _quality = 'large';

  void _stepQuality(int dir) {
    const levels = DirectYouTubeController.qualityLevels;
    final i = (levels.indexOf(_quality) + dir).clamp(0, levels.length - 1);
    _playerCtrl.setQuality(levels[i]);
    setState(() => _quality = levels[i]);
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
    if (correct) _correctCount++;
    correct ? WebSfx.correct() : WebSfx.wrong();
    _addScore(delta);
    _playerCtrl.showScorePopup(delta);
    widget.onAnswered?.call(correct);
    _updateTicks(correct);
    ref
        .read(videoRepositoryProvider)
        .bumpAnswerStat(correct, points: delta > 0 ? delta : 0);
    ref.invalidate(dailyAnswerStatsProvider); // daily quests progress
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

  // ── Inline panels (playlist / word meaning / report) ───────────────────────
  // They overlay the POST-PLAYER area (subtitle + options), never the video:
  // the player and its natural flow are completely untouched.
  _PanelKind? _panel;
  String _panelWord = '';

  void _openPanel(_PanelKind kind, {String word = ''}) {
    if (_panel == kind && (kind != _PanelKind.word || word == _panelWord)) {
      _closePanel();
      return;
    }
    setState(() {
      _panel = kind;
      _panelWord = word;
    });
  }

  void _closePanel() {
    if (_panel == null) return;
    setState(() => _panel = null);
  }

  void _showWordMeaning(String word) =>
      _openPanel(_PanelKind.word, word: word);

  void _openPlaylistDialog(AppL10n l10n) {
    if (ref.read(currentUserProvider).valueOrNull == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.signInForPlaylists)));
      return;
    }
    _openPanel(_PanelKind.playlist);
  }

  @override
  Widget build(BuildContext context) {
    final seg = _seg;
    final lang = ref.watch(localeProvider).languageCode;
    final l10n = AppL10n.fromCode(lang);
    final quizCorrect = seg.quiz.correctFor(lang);
    final quizWrong = seg.quiz.wrongFor(lang);
    final hasQuiz = quizCorrect.isNotEmpty && quizWrong.isNotEmpty;

    return SingleChildScrollView(
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
                onWatched: (s) => _videoRepo.bumpWatchSeconds(s),
                countdown: _countdown,
                showCountdown: _countdownActive,
                showReplay: _clipEnded && !_replaying,
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
            quality: _quality,
            onQualityDown: () => _stepQuality(-1),
            onQualityUp: () => _stepQuality(1),
            // Practice tab only — the Öğren phases show neither.
            ticks: widget.phaseMode ? null : _ticks,
            onAddToPlaylist:
                widget.phaseMode ? null : () => _openPlaylistDialog(l10n),
            playlistTooltip: l10n.addToPlaylist,
          ),

          // ── Post-clip area ────────────────────────────────────────────────
          // The inline panels (playlist / word meaning / report) overlay THIS
          // region — the player above keeps its natural flow, untouched.
          Stack(
            children: [
              ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: _panel != null ? 300 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_clipEnded) ...[
                      const SizedBox(height: 14),

                      // Step 1: choice (Subtitles On | Subtitles Off) — only
                      // while the choice window is open.
                      if (_subtitleChoice == null && !_timedOut)
                        _SubtitleChoiceButtons(
                          onLabel: l10n.subtitlesOn,
                          offLabel: l10n.subtitlesOff,
                          onWithSubtitle: _pickWithSubtitle,
                          onWithoutSubtitle: _pickWithoutSubtitle,
                        ),

                      // Step 2: after a choice → the two answer options always
                      // show; the Chinese subtitle bar only when toggled on.
                      if (_subtitleChoice != null) ...[
                        GestureDetector(
                          onTap: _toggleSubtitle,
                          child: _subtitleChoice == true
                              ? _ChineseSubtitleBar(
                                  words: seg.targetWords.isNotEmpty
                                      ? seg.targetWords
                                      : [seg.subtitleText],
                                  onWordTap: _showWordMeaning,
                                )
                              : _SubtitleRevealBar(label: l10n.subtitleTitle),
                        ),
                        const SizedBox(height: 14),
                        if (hasQuiz)
                          _AnswerRow(
                            correct: quizCorrect,
                            wrong: quizWrong,
                            swap: _optSwap,
                            selected: _pickedAnswer,
                            revealed: _pickedAnswer != null || _timedOut,
                            onPick: _onPick,
                          ),
                        // "Sorun Bildir" — bottom-right, under the options.
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () =>
                                  _openPanel(_PanelKind.report),
                              icon:
                                  const Icon(Icons.flag_outlined, size: 15),
                              label: Text(l10n.reportProblem,
                                  style: const TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                  foregroundColor:
                                      AppColors.onSurfaceMuted),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              // The card floats OVER the options (they stay visible around
              // it) — only its own footprint is covered, nothing is removed.
              if (_panel != null)
                Positioned(
                  top: 8,
                  left: 12,
                  right: 12,
                  child: Center(
                    // One fixed footprint for every panel card, so the word
                    // popup and "Listeye Ekle" open at the SAME size.
                    child: SizedBox(
                      width: 320,
                      child: Material(
                        elevation: 12,
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.transparent,
                        child: switch (_panel!) {
                          _PanelKind.word => _WordMeaningCard(
                              word: _panelWord, onClose: _closePanel),
                          _PanelKind.playlist => _PlaylistCard(
                              videoId: _seg.videoId, onClose: _closePanel),
                          _PanelKind.report => _ReportCard(
                              videoId: _seg.videoId, onClose: _closePanel),
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

enum _PanelKind { playlist, word, report }

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
  // Manual video quality (suggestion to YouTube): current label + steppers.
  final String quality;
  final VoidCallback onQualityDown;
  final VoidCallback onQualityUp;
  // Practice extras (null in phase mode): mastery ticks + playlist button.
  final int? ticks;
  final VoidCallback? onAddToPlaylist;
  final String playlistTooltip;

  const _ControlsBar({
    required this.speed,
    required this.soundOn,
    required this.onToggleSound,
    required this.onPrev,
    required this.onReplay,
    required this.onSpeedChanged,
    required this.quality,
    required this.onQualityDown,
    required this.onQualityUp,
    this.ticks,
    this.onAddToPlaylist,
    this.playlistTooltip = '',
  });

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5];

  static const _qualityLabels = {
    'small': '240p',
    'medium': '360p',
    'large': '480p',
    'hd720': '720p',
    'hd1080': '1080p',
  };

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
              tooltip: AppL10n.of(context).prevTooltip),
          _CtrlBtn(
              icon: Icons.replay_rounded,
              onTap: onReplay,
              size: 24,
              tooltip: AppL10n.of(context).replayTooltip),

          // Sound toggle — same plain pattern as the play button (no builder).
          _CtrlBtn(
            icon: soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            onTap: onToggleSound,
            size: 26,
            tooltip: soundOn
                ? AppL10n.of(context).soundOffTip
                : AppL10n.of(context).soundOnTip,
            color: soundOn ? null : AppColors.primary,
          ),
          if (onAddToPlaylist != null)
            _CtrlBtn(
              icon: Icons.playlist_add_rounded,
              onTap: onAddToPlaylist!,
              size: 26,
              tooltip: playlistTooltip,
            ),

          // Mastery ticks sit left of centre; quality + speed share the right
          // side at even spacing.
          if (ticks != null) ...[
            const SizedBox(width: 14),
            _TickRow(count: ticks!),
          ],
          const Spacer(),

          // Quality stepper: − label + (left of the speed chips).
          _CtrlBtn(
              icon: Icons.remove_rounded,
              onTap: onQualityDown,
              size: 20,
              tooltip: AppL10n.of(context).qualityDownTip),
          SizedBox(
            width: 44,
            child: Text(
              _qualityLabels[quality] ?? quality,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.text70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ),
          _CtrlBtn(
              icon: Icons.add_rounded,
              onTap: onQualityUp,
              size: 20,
              tooltip: AppL10n.of(context).qualityUpTip),
          const SizedBox(width: 14),

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

// Five mastery ticks: one turns PERMANENTLY green per correct answer on this
// video; a wrong answer/timeout takes one back (0..5, stored per user).
class _TickRow extends StatelessWidget {
  final int count;
  const _TickRow({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: i < count
                  ? AppColors.correctAnswer
                  : AppColors.onSurfaceMuted.withValues(alpha: 0.35),
            ),
          ),
      ],
    );
  }
}

// ── Playlist card (inline, below the player) ──────────────────────────────────
// VoScreen-style "Add to Playlist": tick the lists this clip belongs to, or
// create a new named list (the clip is added to it right away).

class _PlaylistCard extends ConsumerStatefulWidget {
  final String videoId;
  final VoidCallback onClose;
  const _PlaylistCard({required this.videoId, required this.onClose});

  @override
  ConsumerState<_PlaylistCard> createState() => _PlaylistCardState();
}

class _PlaylistCardState extends ConsumerState<_PlaylistCard> {
  final _nameCtrl = TextEditingController();
  Set<String> _inLists = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref
        .read(videoRepositoryProvider)
        .playlistsContaining(widget.videoId)
        .then((s) {
      if (mounted) setState(() => _inLists = s);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggle(String playlistId) async {
    final repo = ref.read(videoRepositoryProvider);
    final adding = !_inLists.contains(playlistId);
    setState(() => adding
        ? _inLists.add(playlistId)
        : _inLists.remove(playlistId));
    if (adding) {
      await repo.addToPlaylist(playlistId, widget.videoId);
    } else {
      await repo.removeFromPlaylist(playlistId, widget.videoId);
    }
    ref.invalidate(videoFeedProvider); // a playlist scope may be active
  }

  Future<void> _createAndAdd() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(videoRepositoryProvider);
      final pid = await repo.createPlaylist(name);
      if (pid != null) {
        await repo.addToPlaylist(pid, widget.videoId);
        ref.invalidate(myPlaylistsProvider);
        if (mounted) {
          setState(() {
            _inLists.add(pid);
            _nameCtrl.clear();
          });
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.fromCode(ref.watch(localeProvider).languageCode);
    final playlists =
        ref.watch(myPlaylistsProvider).valueOrNull ?? const [];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.onSurfaceMuted.withValues(alpha: 0.25)),
      ),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: Text(l10n.addToPlaylist,
                    style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: Icon(Icons.close,
                    color: AppColors.onSurfaceMuted, size: 18),
                onPressed: widget.onClose,
              ),
            ]),
            const SizedBox(height: 4),
            if (playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l10n.noPlaylistsYet,
                    style: TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 13)),
              )
            else
              // NOT a shrink-wrapped ListView: AlertDialog measures its content
              // with intrinsics, which ListView doesn't support (blank dialog).
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    for (final p in playlists)
                      InkWell(
                        onTap: () => _toggle(p['id'] as String),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 9),
                          child: Row(
                            children: [
                              Icon(
                                _inLists.contains(p['id'])
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked,
                                size: 20,
                                color: _inLists.contains(p['id'])
                                    ? AppColors.correctAnswer
                                    : AppColors.onSurfaceMuted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  p['name'] as String? ?? '',
                                  style: TextStyle(
                                      color: AppColors.onSurface,
                                      fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Divider(color: AppColors.surface, height: 20),
            TextField(
              controller: _nameCtrl,
              maxLength: 60,
              style: TextStyle(
                  color: AppColors.onSurface, fontSize: 14),
              decoration: InputDecoration(
                hintText: l10n.newPlaylistHint,
                hintStyle:
                    TextStyle(color: AppColors.onSurfaceMuted),
                counterText: '',
                filled: true,
                fillColor: AppColors.surface,
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _createAndAdd(),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _createAndAdd,
              icon: const Icon(Icons.playlist_add_rounded, size: 18),
              label: Text(l10n.createAndAdd),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary),
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
                  fontFamily: _kComic,
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

// ── Subtitle reveal bar (shown when subtitles are OFF) ───────────────────────
// Uses the EXACT outer metrics of _ChineseSubtitleBar (margin/padding/radius +
// a single line at fontSize 20) so toggling to the real subtitle does not change
// the height and the answer options stay put.

class _SubtitleRevealBar extends StatelessWidget {
  final String label;
  const _SubtitleRevealBar({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.onSurfaceMuted.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.onSurfaceMuted.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.closed_caption_off_outlined,
              size: 17, color: AppColors.onSurfaceMuted),
          const SizedBox(width: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              fontFamily: _kComic,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chinese subtitle bar (VoScreen style, appears when Altyazılı chosen) ─────
// Multi-sentence clips store line breaks in the text, so a multi-line subtitle
// renders stacked automatically (Text honours '\n').

class _ChineseSubtitleBar extends StatelessWidget {
  // Confirmed word list ('\n' = line break) rendered as admin-style chips —
  // tapping a chip opens the instant dictionary popup.
  final List<String> words;
  final void Function(String word) onWordTap;
  const _ChineseSubtitleBar({required this.words, required this.onWordTap});

  static final _cjk = RegExp(r'[一-鿿]');

  @override
  Widget build(BuildContext context) {
    // Compact: small chips, and multi-sentence clips stay on the SAME line —
    // a visible "丨" divider separates the sentences instead of a new row, so
    // the answer options never get pushed down (no scrolling while watching).
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        // The bar stays dark so the white hanzi keep their contrast, but the
        // light theme gets the softer brand teal instead of near-black ink.
        color: AppColors.dark
            ? const Color(0xFF1C2624)
            : const Color(0xFF2E6B65),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final w in words)
            if (w == '\n')
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('丨',
                    style: TextStyle(
                        color: Color(0xFF2EC4B6),
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
              )
            else if (_cjk.hasMatch(w))
              Material(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onWordTap(w),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: Text(
                      w,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        fontFamily: _kComic,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              )
            else
              Text(
                w,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontFamily: _kComic,
                  height: 1.25,
                ),
              ),
        ],
      ),
    );
  }
}

// Inline mini dictionary card for a tapped subtitle word. Stateful with the
// lookup cached in initState and a FIXED height — otherwise every parent
// rebuild (the countdown ticks each second) re-created the future and the
// card flickered between its loading and loaded sizes.
class _WordMeaningCard extends ConsumerStatefulWidget {
  final String word;
  final VoidCallback onClose;
  const _WordMeaningCard({required this.word, required this.onClose});

  @override
  ConsumerState<_WordMeaningCard> createState() => _WordMeaningCardState();
}

class _WordMeaningCardState extends ConsumerState<_WordMeaningCard> {
  late final Future<DictionaryModel?> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(dictionaryRepositoryProvider).loadWord(widget.word);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider).languageCode;
    final word = widget.word;
    return Container(
      height: 168,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.onSurfaceMuted.withValues(alpha: 0.25)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              icon: Icon(Icons.close,
                  color: AppColors.onSurfaceMuted, size: 18),
              onPressed: widget.onClose,
            ),
          ),
          Padding(
        padding: const EdgeInsets.only(right: 36, top: 4),
        child: SingleChildScrollView(
        child: FutureBuilder(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 80,
                child: Center(
                    child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }
            final w = snap.data;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(word,
                    style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 36,
                        fontWeight: FontWeight.w800)),
                if (w != null) ...[
                  const SizedBox(height: 2),
                  Text(w.pinyin,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                    w.definitions.forLang(lang),
                    style: TextStyle(
                        color: AppColors.onSurface, fontSize: 15),
                  ),
                  if (w.hskLevel > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.forHskLevel(w.hskLevel),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                          AppL10n.fromCode(lang).hskLabel(w.hskLevel),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      AppL10n.fromCode(lang).notInDict,
                      style: TextStyle(
                          color: AppColors.onSurfaceMuted, fontSize: 13),
                    ),
                  ),
              ],
            );
          },
        ),
        ),
          ),
        ],
      ),
    );
  }
}

// Inline "Sorun Bildir" card: a 300-char note about this clip; confirming
// stores it for the admin Bildirimler tab and closes the card.
class _ReportCard extends ConsumerStatefulWidget {
  final String videoId;
  final VoidCallback onClose;
  const _ReportCard({required this.videoId, required this.onClose});

  @override
  ConsumerState<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends ConsumerState<_ReportCard> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = _ctrl.text.trim();
    if (msg.isEmpty || _sending) return;
    setState(() => _sending = true);
    final l10n = AppL10n.fromCode(ref.read(localeProvider).languageCode);
    try {
      await ref.read(videoRepositoryProvider).reportVideo(widget.videoId, msg);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.reportThanks)));
      widget.onClose();
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.fromCode(ref.watch(localeProvider).languageCode);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.onSurfaceMuted.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.flag_outlined,
                size: 16, color: AppColors.onSurfaceMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(l10n.reportProblem,
                  style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ),
            IconButton(
              icon: Icon(Icons.close,
                  color: AppColors.onSurfaceMuted, size: 18),
              onPressed: widget.onClose,
            ),
          ]),
          TextField(
            controller: _ctrl,
            maxLength: 300,
            maxLines: 3,
            minLines: 2,
            style: TextStyle(color: AppColors.onSurface, fontSize: 14),
            decoration: InputDecoration(
              hintText: l10n.reportHint,
              hintStyle: TextStyle(
                  color: AppColors.onSurfaceMuted, fontSize: 13),
              counterStyle: TextStyle(
                  color: AppColors.onSurfaceMuted, fontSize: 11),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send_rounded, size: 16),
              label: Text(l10n.reportSend),
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ),
        ],
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
              fontFamily: _kComic,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ── No-quiz fallback ──────────────────────────────────────────────────────────
