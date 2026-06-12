import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/locale_provider.dart';
import '../../providers/path_provider.dart';
import '../../providers/user_provider.dart';
import '../home/inline_player_section.dart';

const _duoGreen = Color(0xFF2EC4B6);
const _duoGreenDark = Color(0xFF21968B);
const _duoBg = Color(0xFF0E1414);
const _duoTrack = Color(0xFF2E3A38);

// Duolingo-style lesson view: top bar (X + segmented progress + hearts), the
// video exercise centered, and a result screen at the end. Plays the phase's
// videos in order; ≥ kPassRatio correct clears the phase.
class PhaseRunnerScreen extends ConsumerStatefulWidget {
  final PathPhase phase;
  final String title;
  const PhaseRunnerScreen({super.key, required this.phase, required this.title});

  @override
  ConsumerState<PhaseRunnerScreen> createState() => _PhaseRunnerScreenState();
}

class _PhaseRunnerScreenState extends ConsumerState<PhaseRunnerScreen> {
  int _index = 0;
  int _wrong = 0;
  int? _startHearts;
  bool _saving = false;
  ({int correct, int total, bool passed})? _result;

  Future<void> _onComplete(int correct, int total) async {
    final passed = total == 0 ? false : correct / total >= kPassRatio;
    setState(() {
      _saving = true;
      _result = (correct: correct, total: total, passed: passed);
    });
    try {
      await ref.read(userRepositoryProvider).savePhaseResult(
            widget.phase.key,
            correct: correct,
            total: total,
            done: passed,
          );
      ref.invalidate(pathProgressProvider);
    } catch (_) {}
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.phase.videos.length;
    _startHearts ??= ref.read(pathMetaProvider).hearts;
    final heartsNow = (_startHearts! - _wrong).clamp(0, 5);
    return Scaffold(
      backgroundColor: _duoBg,
      body: SafeArea(
        child: _result != null
            ? _ResultView(
                correct: _result!.correct,
                total: _result!.total,
                passed: _result!.passed,
                saving: _saving)
            : Column(
                children: [
                  // Top bar: X + segmented progress + hearts
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white54, size: 28),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: total == 0 ? 0 : (_index) / total,
                              minHeight: 16,
                              backgroundColor: _duoTrack,
                              valueColor:
                                  const AlwaysStoppedAnimation(_duoGreen),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.favorite_rounded,
                            color: Color(0xFFFF4B4B), size: 24),
                        const SizedBox(width: 4),
                        Text('$heartsNow',
                            style: const TextStyle(
                                color: Color(0xFFFF4B4B),
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  Expanded(
                    // Top-anchored (NOT centred): when the options appear the
                    // player must stay exactly where it is — only the area
                    // below grows.
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 880),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                          child: InlinePlayerSection(
                            segments: widget.phase.videos,
                            phaseMode: true,
                            onPhaseComplete: _onComplete,
                            onIndexChanged: (i) =>
                                setState(() => _index = i),
                            onAnswered: (correct) {
                              if (!correct) setState(() => _wrong++);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final int correct;
  final int total;
  final bool passed;
  final bool saving;
  const _ResultView({
    required this.correct,
    required this.total,
    required this.passed,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    final color = passed ? _duoGreen : const Color(0xFFFF4B4B);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(passed ? Icons.emoji_events_rounded : Icons.refresh_rounded,
              color: color, size: 80),
          const SizedBox(height: 16),
          Text(
            passed
                ? AppL10n.of(context).phasePassed
                : AppL10n.of(context).phaseFailed,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(AppL10n.of(context).correctOf(correct, total),
              style: const TextStyle(color: Colors.white60, fontSize: 16)),
          if (!passed) ...[
            const SizedBox(height: 4),
            Text(AppL10n.of(context).passReq((kPassRatio * 100).round()),
                style: const TextStyle(color: Colors.white38, fontSize: 13)),
          ],
          const SizedBox(height: 28),
          if (saving)
            const CircularProgressIndicator(color: _duoGreen)
          else
            SizedBox(
              width: 240,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(passed),
                style: FilledButton.styleFrom(
                  backgroundColor: passed ? _duoGreen : color,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  shadowColor: _duoGreenDark,
                ),
                child: Text(
                    passed
                        ? AppL10n.of(context).continueCaps
                        : AppL10n.of(context).goBackCaps,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}
