import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/path_provider.dart';
import '../../providers/user_provider.dart';
import '../home/inline_player_section.dart';

// Plays one phase: the phase's videos in order, "answer to advance". On the last
// answer it scores the phase; ≥ kPassRatio correct clears it (unlocks the next).
class PhaseRunnerScreen extends ConsumerStatefulWidget {
  final PathPhase phase;
  final String title; // e.g. "HSK 2 · Adım 3 · Faz 2"
  const PhaseRunnerScreen({super.key, required this.phase, required this.title});

  @override
  ConsumerState<PhaseRunnerScreen> createState() => _PhaseRunnerScreenState();
}

class _PhaseRunnerScreenState extends ConsumerState<PhaseRunnerScreen> {
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
    } catch (_) {/* keep the result UI; user can retry */}
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceVariant,
        title: Text(widget.title, style: const TextStyle(fontSize: 15)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _result != null
          ? _ResultView(
              correct: _result!.correct,
              total: _result!.total,
              passed: _result!.passed,
              saving: _saving,
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: InlinePlayerSection(
                    segments: widget.phase.videos,
                    phaseMode: true,
                    onPhaseComplete: _onComplete,
                  ),
                ),
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
    final color = passed ? AppColors.correctAnswer : AppColors.wrongAnswer;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(passed ? Icons.emoji_events_rounded : Icons.refresh_rounded,
              color: color, size: 72),
          const SizedBox(height: 16),
          Text(
            passed ? 'Tebrikler! Faz tamamlandı' : 'Bu sefer olmadı',
            style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('$correct / $total doğru',
              style: const TextStyle(
                  color: AppColors.onSurfaceMuted, fontSize: 16)),
          if (!passed) ...[
            const SizedBox(height: 4),
            Text('Geçmek için en az %${(kPassRatio * 100).round()}',
                style: const TextStyle(
                    color: AppColors.onSurfaceMuted, fontSize: 13)),
          ],
          const SizedBox(height: 28),
          if (saving)
            const CircularProgressIndicator(color: AppColors.primary)
          else
            FilledButton(
              onPressed: () => Navigator.of(context).pop(passed),
              style: FilledButton.styleFrom(
                backgroundColor: passed ? AppColors.primary : color,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: Text(passed ? 'Devam Et' : 'Geri Dön',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
