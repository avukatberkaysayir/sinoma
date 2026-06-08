import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/video_segment_model.dart';
import 'user_provider.dart';
import 'video_provider.dart';

// ── Tuning ────────────────────────────────────────────────────────────────────
const int kPhaseSize = 8; // target videos per phase
const int kPhasesPerStep = 4;
const double kPassRatio = 0.6; // ≥60% correct to clear a phase
// TEMP: unlock every circle on ALL levels so the gözat words can be inspected
// freely. Revert to false once review is done.
const bool kUnlockAll = true;

// ── Curriculum model ──────────────────────────────────────────────────────────

class PathPhase {
  final int hsk;
  final int stepIndex;
  final int phaseIndex; // within the unit (0..3)
  final List<VideoSegmentModel> videos;
  const PathPhase({
    required this.hsk,
    required this.stepIndex,
    required this.phaseIndex,
    required this.videos,
  });

  String get key => 'hsk$hsk.s$stepIndex.p$phaseIndex';
  // Matches WordSlot.slotKey (1-based level/unit/phase) for the "gözat" panel.
  String get wordSlotKey => 'L$hsk.u${stepIndex + 1}.p${phaseIndex + 1}';
  bool get hasVideos => videos.isNotEmpty;
}

class PathStep {
  final int hsk;
  final int index;
  final String title; // grammar point (Chinese) or unit label
  final String? grammarName; // QuizCategory.name this unit teaches (null = empty)
  final List<PathPhase> phases; // always 4; phases without videos are locked
  const PathStep({
    required this.hsk,
    required this.index,
    required this.title,
    required this.grammarName,
    required this.phases,
  });

  bool get hasContent => phases.any((p) => p.hasVideos);
}

class PathTopic {
  final int hsk;
  final List<PathStep> steps;
  const PathTopic({required this.hsk, required this.steps});
}

// Build the curriculum: levels L1-L6 (= HSK 1-6). Each level has kUnitsPerLevel
// units; unit u teaches grammar point kGrammarByHsk[hsk][u] (units past the
// grammar list are empty/locked placeholders). Each unit has kPhasesPerStep
// phases; videos tagged with the unit's grammar fill the phases in order, the
// rest stay locked. (Video→grammar tagging is curated separately in the admin.)
// The grammar this video primarily teaches: the first tag that maps to a level.
String? primaryGrammarOf(VideoSegmentModel v) {
  for (final c in v.categoryTags) {
    if (hskOfGrammar(c) != null) return c;
  }
  return v.categoryTags.isNotEmpty ? v.categoryTags.first : null;
}

// A vocabulary word pinned to a path slot (level/unit/phase), with its meaning.
class WordSlot {
  final String word;
  final int level;
  final int unit;
  final int phase;
  final String pinyin;
  final String tr;
  final String en;
  const WordSlot({
    required this.word,
    required this.level,
    required this.unit,
    required this.phase,
    this.pinyin = '',
    this.tr = '',
    this.en = '',
  });

  String get slotKey => 'L$level.u$unit.p$phase';

  factory WordSlot.fromMap(Map<String, dynamic> m) => WordSlot(
        word: m['word'] as String? ?? '',
        level: (m['level'] as num?)?.toInt() ?? 1,
        unit: (m['unit'] as num?)?.toInt() ?? 1,
        phase: (m['phase'] as num?)?.toInt() ?? 1,
        pinyin: m['pinyin'] as String? ?? '',
        tr: m['tr'] as String? ?? '',
        en: m['en'] as String? ?? '',
      );
}

List<PathTopic> buildCurriculum(List<VideoSegmentModel> all,
    [Map<int, List<GrammarMeta>> grammarByLevel = const {}]) {
  // slot[hsk][unitIndex][phaseIndex] -> videos placed there.
  final slot = <int, List<List<List<VideoSegmentModel>>>>{
    for (var hsk = 1; hsk <= 6; hsk++)
      hsk: [
        for (var u = 0; u < kUnitsPerLevel; u++)
          [for (var p = 0; p < kPhasesPerStep; p++) <VideoSegmentModel>[]],
      ],
  };

  final sorted = all.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // Pass 1 — explicit manual placement (admin-set unit + phase). Level (L) is
  // derived from the grammar rule.
  final placed = <String>{};
  for (final v in sorted) {
    if (v.unit == null || v.phase == null) continue;
    // phase 0 = "Diğer" (ungrouped holding bucket): kept out of the path but
    // still considered placed so the fallback doesn't re-add it.
    if (v.phase == 0) {
      placed.add(v.videoId);
      continue;
    }
    final l = v.level ?? hskOfGrammar(primaryGrammarOf(v)) ?? v.hskLevel;
    final u = v.unit! - 1, p = v.phase! - 1;
    if (l < 1 || l > 6) continue;
    if (u < 0 || u >= kUnitsPerLevel || p < 0 || p >= kPhasesPerStep) continue;
    slot[l]![u][p].add(v);
    placed.add(v.videoId);
  }

  // (Grammar-less HSK1 clips are pinned to a word slot at write time by the
  // trg_assign_video_path trigger — one clip per slot word — so they arrive here
  // already carrying level/unit/phase and are handled by Pass 1 above.)

  // Pass 2 — fallback for un-placed videos: group by the grammar's natural unit
  // and fill its phases in order (keeps the path populated before curation).
  for (var hsk = 1; hsk <= 6; hsk++) {
    final grammar = kGrammarByHsk[hsk] ?? const <QuizCategory>[];
    final unitOf = {for (var u = 0; u < grammar.length; u++) grammar[u].name: u};
    final byUnit = <int, List<VideoSegmentModel>>{};
    for (final v in sorted) {
      if (placed.contains(v.videoId)) continue;
      if (!v.hskLevelTags.contains(hsk)) continue;
      final g = primaryGrammarOf(v);
      final u = g == null ? null : unitOf[g];
      if (u == null) continue;
      (byUnit[u] ??= []).add(v);
    }
    byUnit.forEach((u, vids) {
      for (var i = 0; i < vids.length; i++) {
        final p = (i ~/ kPhaseSize).clamp(0, kPhasesPerStep - 1);
        slot[hsk]![u][p].add(vids[i]);
      }
    });
  }

  final topics = <PathTopic>[];
  for (var hsk = 1; hsk <= 6; hsk++) {
    final levelGrammars = grammarByLevel[hsk] ?? const <GrammarMeta>[];
    final steps = <PathStep>[];
    for (var u = 0; u < kUnitsPerLevel; u++) {
      // A unit can teach several grammar rules (the expanded function-word set).
      final unitG = levelGrammars.where((g) => g.unit == u + 1).toList();
      final phases = <PathPhase>[
        for (var p = 0; p < kPhasesPerStep; p++)
          PathPhase(
            hsk: hsk,
            stepIndex: u,
            phaseIndex: p,
            videos: slot[hsk]![u][p],
          ),
      ];
      steps.add(PathStep(
        hsk: hsk,
        index: u,
        title: unitG.isEmpty ? '—' : unitG.map((g) => g.zh).join(' · '),
        grammarName: unitG.isEmpty ? null : unitG.first.name,
        phases: phases,
      ));
    }
    topics.add(PathTopic(hsk: hsk, steps: steps));
  }
  return topics;
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

// The "continue where you left off" phase: the first unlocked, not-done phase
// scanning HSK 1→6 in order. Null when there's nothing to do (no content / all
// done).
PathPhase? currentPhaseFor(
    List<PathTopic> topics, Map<String, dynamic> progress) {
  for (final t in topics) {
    for (final s in t.steps) {
      for (final p in s.phases) {
        if (!progress.phase(p.key).done && isPhaseUnlocked(t, p, progress)) {
          return p;
        }
      }
    }
  }
  return null;
}

// A phase is unlocked if it's the first PLAYABLE phase in the topic or the
// previous playable phase is done. Empty (content-less) phases are not part of
// the chain — they render locked and never block content that comes after them.
bool isPhaseUnlocked(
    PathTopic topic, PathPhase phase, Map<String, dynamic> progress) {
  if (kUnlockAll) return true; // TEMP inspection override (all levels)
  if (!phase.hasVideos) return false;
  final flat = <PathPhase>[
    for (final s in topic.steps)
      for (final p in s.phases)
        if (p.hasVideos) p
  ];
  final idx = flat.indexWhere((p) => p.key == phase.key);
  if (idx <= 0) return true;
  return progress.phase(flat[idx - 1].key).done;
}

// ── Providers ─────────────────────────────────────────────────────────────────

final allActiveVideosProvider = FutureProvider<List<VideoSegmentModel>>((ref) {
  return ref.watch(videoRepositoryProvider).loadAllActiveSegments();
});

// Grammar curriculum metadata from the DB (grammar_levels) — the source of truth
// for the expanded function-word grammar set (the Dart const maps no longer cover
// it). Used for chips, the Gramer dropdown, unit titles and the criterion label.
class GrammarMeta {
  final String name;
  final int level;
  final int unit;
  final String? symbol;
  final String zh;
  final String tr;
  final String en;
  const GrammarMeta({
    required this.name,
    required this.level,
    required this.unit,
    required this.symbol,
    required this.zh,
    required this.tr,
    required this.en,
  });
  factory GrammarMeta.fromMap(Map<String, dynamic> m) => GrammarMeta(
        name: m['name'] as String? ?? '',
        level: (m['level'] as num?)?.toInt() ?? 1,
        unit: (m['unit'] as num?)?.toInt() ?? 1,
        symbol: m['symbol'] as String?,
        zh: m['zh'] as String? ?? (m['symbol'] as String? ?? ''),
        tr: m['tr'] as String? ?? '',
        en: m['en'] as String? ?? '',
      );
}

final grammarMetaProvider = FutureProvider<List<GrammarMeta>>((ref) async {
  final rows = await ref.watch(videoRepositoryProvider).loadGrammarMeta();
  return rows.map(GrammarMeta.fromMap).toList();
});

final grammarByNameProvider = Provider<Map<String, GrammarMeta>>((ref) {
  final list = ref.watch(grammarMetaProvider).valueOrNull ?? const [];
  return {for (final g in list) g.name: g};
});

final grammarByLevelProvider = Provider<Map<int, List<GrammarMeta>>>((ref) {
  final list = ref.watch(grammarMetaProvider).valueOrNull ?? const [];
  final m = <int, List<GrammarMeta>>{};
  for (final g in list) {
    (m[g.level] ??= []).add(g);
  }
  return m;
});

// Words pinned to one slot, fetched on demand for the "gözat" panel (per-slot
// query avoids PostgREST's 1000-row cap that left higher levels empty).
final slotWordsProvider = FutureProvider.family<List<WordSlot>,
    ({int level, int unit, int phase})>((ref, k) async {
  final rows = await ref
      .watch(videoRepositoryProvider)
      .loadWordsForSlot(k.level, k.unit, k.phase);
  return rows.map(WordSlot.fromMap).toList();
});

final curriculumProvider = FutureProvider<List<PathTopic>>((ref) async {
  final vids = await ref.watch(allActiveVideosProvider.future);
  await ref.watch(grammarMetaProvider.future); // ensure metadata is loaded
  return buildCurriculum(vids, ref.read(grammarByLevelProvider));
});

final pathProgressProvider = FutureProvider<Map<String, dynamic>>((ref) {
  // Re-read when the signed-in uid changes.
  ref.watch(authUidProvider.select((a) => a.valueOrNull));
  return ref.watch(userRepositoryProvider).loadPathProgress();
});

// Which HSK topic the path screen is showing.
final selectedTopicHskProvider = StateProvider<int>((ref) => 1);

// ── Gamification: hearts (lives) + streak ─────────────────────────────────────
const int kMaxHearts = 5;
const Duration kHeartRefill = Duration(hours: 4); // +1 heart every 4h

class PathMeta {
  final int hearts; // live count (refill applied)
  final int streak; // consecutive active days
  final DateTime? nextHeartAt; // when the next heart refills (null if full)
  const PathMeta({this.hearts = kMaxHearts, this.streak = 0, this.nextHeartAt});
}

// Hearts/streak live in path_progress under the "__meta" key:
// {hearts, heartsTs(ISO), streak, lastActive(yyyy-mm-dd)}.
PathMeta computeMeta(Map<String, dynamic> progress) {
  final m = progress['__meta'];
  if (m is! Map) return const PathMeta();
  var hearts = (m['hearts'] as int?) ?? kMaxHearts;
  final ts = DateTime.tryParse((m['heartsTs'] as String?) ?? '');
  DateTime? nextAt;
  if (hearts < kMaxHearts && ts != null) {
    final elapsed = DateTime.now().difference(ts);
    final refills = elapsed.inMinutes ~/ kHeartRefill.inMinutes;
    hearts = (hearts + refills).clamp(0, kMaxHearts);
    if (hearts < kMaxHearts) {
      nextAt = ts.add(kHeartRefill * (refills + 1));
    }
  }
  return PathMeta(
      hearts: hearts, streak: (m['streak'] as int?) ?? 0, nextHeartAt: nextAt);
}

final pathMetaProvider = Provider<PathMeta>((ref) {
  final p = ref.watch(pathProgressProvider).valueOrNull ?? const {};
  return computeMeta(p);
});

final leaderboardProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(authUidProvider.select((a) => a.valueOrNull));
  return ref.watch(userRepositoryProvider).loadLeaderboard();
});
