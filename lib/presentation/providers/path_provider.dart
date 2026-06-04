import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/video_segment_model.dart';
import 'user_provider.dart';
import 'video_provider.dart';

// ── Tuning ────────────────────────────────────────────────────────────────────
const int kPhaseSize = 8; // target videos per phase
const int kPhasesPerStep = 4;
const double kPassRatio = 0.6; // ≥60% correct to clear a phase

// ── Curriculum model ──────────────────────────────────────────────────────────

class PathPhase {
  final int hsk;
  final int stepIndex;
  final int phaseIndex; // within the step (0..3)
  final List<VideoSegmentModel> videos;
  const PathPhase({
    required this.hsk,
    required this.stepIndex,
    required this.phaseIndex,
    required this.videos,
  });

  String get key => 'hsk$hsk.s$stepIndex.p$phaseIndex';
}

class PathStep {
  final int hsk;
  final int index;
  final String themeKey; // a LifeCategory.name — UI localizes it
  final List<PathPhase> phases;
  const PathStep({
    required this.hsk,
    required this.index,
    required this.themeKey,
    required this.phases,
  });
}

class PathTopic {
  final int hsk;
  final List<PathStep> steps;
  const PathTopic({required this.hsk, required this.steps});
}

// Build the whole curriculum (HSK 1-6) from the active-video pool. Videos are
// grouped by theme within each HSK level, sliced into phases, 4 phases per step.
List<PathTopic> buildCurriculum(List<VideoSegmentModel> all) {
  final topics = <PathTopic>[];
  for (var hsk = 1; hsk <= 6; hsk++) {
    final pool = all.where((v) => v.hskLevelTags.contains(hsk)).toList();
    // Cluster same-theme clips together so steps/phases are coherent.
    pool.sort((a, b) {
      final ta = a.lifeTags.isNotEmpty ? a.lifeTags.first : '';
      final tb = b.lifeTags.isNotEmpty ? b.lifeTags.first : '';
      final c = ta.compareTo(tb);
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });

    // Slice into phases.
    final phases = <List<VideoSegmentModel>>[];
    for (var i = 0; i < pool.length; i += kPhaseSize) {
      phases.add(pool.sublist(
          i, (i + kPhaseSize) > pool.length ? pool.length : i + kPhaseSize));
    }

    // Group phases into steps of kPhasesPerStep.
    final steps = <PathStep>[];
    for (var s = 0; s * kPhasesPerStep < phases.length; s++) {
      final slice = phases.sublist(
          s * kPhasesPerStep,
          ((s + 1) * kPhasesPerStep) > phases.length
              ? phases.length
              : (s + 1) * kPhasesPerStep);
      final stepVideos = slice.expand((p) => p).toList();
      steps.add(PathStep(
        hsk: hsk,
        index: s,
        themeKey: _dominantTheme(stepVideos),
        phases: [
          for (var p = 0; p < slice.length; p++)
            PathPhase(hsk: hsk, stepIndex: s, phaseIndex: p, videos: slice[p]),
        ],
      ));
    }
    topics.add(PathTopic(hsk: hsk, steps: steps));
  }
  return topics;
}

String _dominantTheme(List<VideoSegmentModel> videos) {
  final counts = <String, int>{};
  for (final v in videos) {
    final t = v.lifeTags.isNotEmpty ? v.lifeTags.first : 'daily_life';
    counts[t] = (counts[t] ?? 0) + 1;
  }
  if (counts.isEmpty) return 'daily_life';
  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

// ── Progress ──────────────────────────────────────────────────────────────────

class PhaseProgress {
  final int correct;
  final int total;
  final bool done;
  const PhaseProgress(
      {this.correct = 0, this.total = 0, this.done = false});
}

extension PathProgressMap on Map<String, dynamic> {
  PhaseProgress phase(String key) {
    final m = this[key];
    if (m is Map) {
      return PhaseProgress(
        correct: (m['correct'] as int?) ?? 0,
        total: (m['total'] as int?) ?? 0,
        done: m['done'] == true,
      );
    }
    return const PhaseProgress();
  }
}

// A phase is unlocked if it's the first in the topic or the PREVIOUS phase (in
// flat order across steps) is done.
bool isPhaseUnlocked(
    PathTopic topic, PathPhase phase, Map<String, dynamic> progress) {
  final flat = <PathPhase>[for (final s in topic.steps) ...s.phases];
  final idx = flat.indexWhere((p) => p.key == phase.key);
  if (idx <= 0) return true;
  return progress.phase(flat[idx - 1].key).done;
}

// ── Providers ─────────────────────────────────────────────────────────────────

final allActiveVideosProvider = FutureProvider<List<VideoSegmentModel>>((ref) {
  return ref.watch(videoRepositoryProvider).loadAllActiveSegments();
});

final curriculumProvider = FutureProvider<List<PathTopic>>((ref) async {
  final vids = await ref.watch(allActiveVideosProvider.future);
  return buildCurriculum(vids);
});

final pathProgressProvider = FutureProvider<Map<String, dynamic>>((ref) {
  // Re-read when the signed-in uid changes.
  ref.watch(authUidProvider.select((a) => a.valueOrNull));
  return ref.watch(userRepositoryProvider).loadPathProgress();
});

// Which HSK topic the path screen is showing.
final selectedTopicHskProvider = StateProvider<int>((ref) => 1);
