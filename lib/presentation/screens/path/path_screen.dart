import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/video_segment_model.dart';
import '../../providers/locale_provider.dart';
import '../../providers/path_provider.dart';
import 'phase_runner_screen.dart';

// Duolingo-style learning path: HSK 1-6 topics, each a vertical map of steps,
// each step a row of phase nodes (done / current / locked). Complete a phase by
// answering enough videos correctly to unlock the next.
class PathScreen extends ConsumerWidget {
  const PathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curriculum = ref.watch(curriculumProvider);
    final progressAsync = ref.watch(pathProgressProvider);
    final selectedHsk = ref.watch(selectedTopicHskProvider);
    final tr = ref.watch(localeProvider).languageCode == 'tr';

    return curriculum.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('${tr ? 'Yüklenemedi' : 'Failed to load'}: $e',
            style: const TextStyle(color: AppColors.onSurfaceMuted)),
      ),
      data: (topics) {
        final progress = progressAsync.valueOrNull ?? const {};
        final topic = topics.firstWhere((t) => t.hsk == selectedHsk,
            orElse: () => topics.first);

        return Column(
          children: [
            _TopicSelector(
              selected: selectedHsk,
              onSelect: (h) =>
                  ref.read(selectedTopicHskProvider.notifier).state = h,
            ),
            Expanded(
              child: topic.steps.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          tr
                              ? 'HSK $selectedHsk için içerik yakında eklenecek.'
                              : 'Content for HSK $selectedHsk is coming soon.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.onSurfaceMuted, fontSize: 15),
                        ),
                      ),
                    )
                  : _TopicMap(topic: topic, progress: progress, tr: tr),
            ),
          ],
        );
      },
    );
  }
}

class _TopicSelector extends StatelessWidget {
  final int selected;
  final void Function(int) onSelect;
  const _TopicSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.surfaceVariant,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var h = 1; h <= 6; h++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onSelect(h),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected == h
                          ? AppColors.forHskLevel(h)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected == h
                            ? AppColors.forHskLevel(h)
                            : AppColors.onSurfaceMuted.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text('HSK $h',
                        style: TextStyle(
                          color: selected == h
                              ? Colors.white
                              : AppColors.onSurfaceMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        )),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopicMap extends ConsumerWidget {
  final PathTopic topic;
  final Map<String, dynamic> progress;
  final bool tr;
  const _TopicMap(
      {required this.topic, required this.progress, required this.tr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The single "current" phase = first unlocked & not-done across the topic.
    final flat = <PathPhase>[for (final s in topic.steps) ...s.phases];
    PathPhase? current;
    for (final p in flat) {
      if (!progress.phase(p.key).done && isPhaseUnlocked(topic, p, progress)) {
        current = p;
        break;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                for (final step in topic.steps)
                  _StepSection(
                    step: step,
                    topic: topic,
                    progress: progress,
                    currentKey: current?.key,
                    tr: tr,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepSection extends StatelessWidget {
  final PathStep step;
  final PathTopic topic;
  final Map<String, dynamic> progress;
  final String? currentKey;
  final bool tr;
  const _StepSection({
    required this.step,
    required this.topic,
    required this.progress,
    required this.currentKey,
    required this.tr,
  });

  @override
  Widget build(BuildContext context) {
    final theme = LifeCategory.labelFor(step.themeKey, isTr: tr);
    return Column(
      children: [
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.forHskLevel(step.hsk).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${tr ? 'Adım' : 'Step'} ${step.index + 1}',
                  style: const TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(theme,
                  style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final phase in step.phases)
          _PhaseNode(
            phase: phase,
            topic: topic,
            progress: progress,
            isCurrent: phase.key == currentKey,
            tr: tr,
          ),
      ],
    );
  }
}

class _PhaseNode extends ConsumerWidget {
  final PathPhase phase;
  final PathTopic topic;
  final Map<String, dynamic> progress;
  final bool isCurrent;
  final bool tr;
  const _PhaseNode({
    required this.phase,
    required this.topic,
    required this.progress,
    required this.isCurrent,
    required this.tr,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pp = progress.phase(phase.key);
    final unlocked = isPhaseUnlocked(topic, phase, progress);
    final done = pp.done;

    final Color bg;
    final Widget icon;
    if (done) {
      bg = AppColors.correctAnswer;
      icon = const Icon(Icons.check_rounded, color: Colors.white, size: 30);
    } else if (unlocked) {
      bg = AppColors.primary;
      icon = const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32);
    } else {
      bg = AppColors.onSurfaceMuted.withValues(alpha: 0.25);
      icon = const Icon(Icons.lock_rounded, color: Colors.white70, size: 22);
    }

    Future<void> open() async {
      if (!unlocked) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PhaseRunnerScreen(
          phase: phase,
          title:
              'HSK ${phase.hsk} · ${tr ? 'Faz' : 'Phase'} ${phase.phaseIndex + 1} '
              '(${phase.videos.length} ${tr ? 'video' : 'videos'})',
        ),
      ));
      ref.invalidate(pathProgressProvider);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          if (isCurrent)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(tr ? 'BAŞLAT' : 'START',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          GestureDetector(
            onTap: open,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.5),
                            blurRadius: 16)
                      ]
                    : null,
              ),
              child: icon,
            ),
          ),
          if (done && pp.total > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${pp.correct}/${pp.total}',
                  style: const TextStyle(
                      color: AppColors.onSurfaceMuted, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}
