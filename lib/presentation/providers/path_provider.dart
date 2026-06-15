import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/video_segment_model.dart';
import 'user_provider.dart';
import 'video_provider.dart';

// ── Tuning ────────────────────────────────────────────────────────────────────
const int kPhaseSize = 8; // target videos per phase
const int kPhasesPerStep = 4;
const double kPassRatio = 0.6; // ≥60% correct to clear a phase
// TEMP override: unlock every circle on ALL levels (inspection only).
const bool kUnlockAll = false;

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
  final String ko;
  final String ja;
  final String id;
  final String vi;
  final String th;
  final String ru;
  final String es;
  final String pt;
  const WordSlot({
    required this.word,
    required this.level,
    required this.unit,
    required this.phase,
    this.pinyin = '',
    this.tr = '',
    this.en = '',
    this.ko = '',
    this.ja = '',
    this.id = '',
    this.vi = '',
    this.th = '',
    this.ru = '',
    this.es = '',
    this.pt = '',
  });

  String get slotKey => 'L$level.u$unit.p$phase';

  // UI display: requested language, English as the universal fallback.
  String meaningFor(String lang) => switch (lang) {
        'tr' => tr.isNotEmpty ? tr : en,
        'ko' => ko.isNotEmpty ? ko : en,
        'ja' => ja.isNotEmpty ? ja : en,
        'id' => id.isNotEmpty ? id : en,
        'vi' => vi.isNotEmpty ? vi : en,
        'th' => th.isNotEmpty ? th : en,
        'ru' => ru.isNotEmpty ? ru : en,
        'es' => es.isNotEmpty ? es : en,
        'pt' => pt.isNotEmpty ? pt : en,
        _ => en,
      };

  factory WordSlot.fromMap(Map<String, dynamic> m) => WordSlot(
        word: m['word'] as String? ?? '',
        level: (m['level'] as num?)?.toInt() ?? 1,
        unit: (m['unit'] as num?)?.toInt() ?? 1,
        phase: (m['phase'] as num?)?.toInt() ?? 1,
        pinyin: m['pinyin'] as String? ?? '',
        tr: m['tr'] as String? ?? '',
        en: m['en'] as String? ?? '',
        ko: m['ko'] as String? ?? '',
        ja: m['ja'] as String? ?? '',
        id: m['id'] as String? ?? '',
        vi: m['vi'] as String? ?? '',
        th: m['th'] as String? ?? '',
        ru: m['ru'] as String? ?? '',
        es: m['es'] as String? ?? '',
        pt: m['pt'] as String? ?? '',
      );
}

List<PathTopic> buildCurriculum(List<VideoSegmentModel> all,
    [Map<int, List<GrammarMeta>> grammarByLevel = const {},
    Map<String, List<String>> unitWords = const {}]) {
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
      // Units with a grammar rule show it; the rest (e.g. most of HSK6, whose
      // dictionary words carry no part-of-speech) show their vocabulary so they
      // never read as empty "Soon" placeholders.
      final words = unitWords['L$hsk.u${u + 1}'] ?? const <String>[];
      steps.add(PathStep(
        hsk: hsk,
        index: u,
        title: unitG.isNotEmpty
            ? unitG.map((g) => g.zh).join(' · ')
            : (words.isEmpty ? '—' : words.join(' · ')),
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
// scanning HSK 1→6 in order. Levels at or below the tested HSK level count as
// already passed — the pointer (BAŞLAT) goes to the first phase ABOVE them
// (HSK 5 test → L6 Ünite 1 Bölüm 1). Null when nothing remains (e.g. HSK 6).
PathPhase? currentPhaseFor(
    List<PathTopic> topics, Map<String, dynamic> progress,
    [int userHskLevel = 0]) {
  for (final t in topics) {
    if (t.hsk <= userHskLevel) continue;
    for (final s in t.steps) {
      for (final p in s.phases) {
        if (!progress.phase(p.key).done &&
            isPhaseUnlocked(t, p, progress, userHskLevel)) {
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
// The HSK placement test opens whole levels: every phase whose topic is at or
// below the user's tested level is playable immediately (no points granted —
// only completing a phase yourself writes progress/score).
bool isPhaseUnlocked(
    PathTopic topic, PathPhase phase, Map<String, dynamic> progress,
    [int userHskLevel = 0]) {
  if (kUnlockAll) return true; // TEMP inspection override (all levels)
  if (!phase.hasVideos) return false;
  if (topic.hsk <= userHskLevel) return true;
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

// Every distinct word of one HSK level (lazy — loaded when a level's word picker
// opens in the YouTube import filter). Via the words_for_level RPC.
final wordsForLevelProvider =
    FutureProvider.family<List<WordSlot>, int>((ref, level) async {
  final rows =
      await ref.watch(videoRepositoryProvider).loadWordsForLevel(level);
  return rows.map(WordSlot.fromMap).toList();
});

// ── Admin-managed home design overrides (banner/photos/icons per unit) ────────
class PathAsset {
  final String? url;
  final double scale;
  final String? descTr;
  final String? descEn;
  const PathAsset({this.url, this.scale = 1.0, this.descTr, this.descEn});
}

class UnitAssets {
  final PathAsset? banner;
  final Map<int, PathAsset> icons; // slot 0..3
  final Map<int, PathAsset> photos; // slot 0..3
  const UnitAssets(
      {this.banner, this.icons = const {}, this.photos = const {}});
  PathAsset icon(int slot) => icons[slot] ?? const PathAsset();
  PathAsset photo(int slot) => photos[slot] ?? const PathAsset();
}

final pathAssetsProvider =
    FutureProvider.family<UnitAssets, ({int level, int unit})>((ref, k) async {
  final rows =
      await ref.watch(videoRepositoryProvider).loadPathAssets(k.level, k.unit);
  PathAsset? banner;
  final icons = <int, PathAsset>{};
  final photos = <int, PathAsset>{};
  for (final r in rows) {
    final a = PathAsset(
      url: r['url'] as String?,
      scale: (r['scale'] as num?)?.toDouble() ?? 1.0,
      descTr: r['desc_tr'] as String?,
      descEn: r['desc_en'] as String?,
    );
    final kind = r['kind'] as String?;
    final slot = (r['slot'] as num?)?.toInt() ?? 0;
    if (kind == 'banner') {
      banner = a;
    } else if (kind == 'icon') {
      icons[slot] = a;
    } else if (kind == 'photo') {
      photos[slot] = a;
    }
  }
  return UnitAssets(banner: banner, icons: icons, photos: photos);
});

// Grammar/word slots that already hold an active clip — flagged red in the filter.
final usedActiveSlotsProvider =
    FutureProvider<({Set<String> grammars, Set<String> words})>((ref) async {
  return ref.watch(videoRepositoryProvider).loadUsedActiveSlots();
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

// A few representative words per unit (keyed 'L{level}.u{unit}') — captions for
// grammar-less units (loaded via the unit_word_summary RPC, one compact query).
final unitWordSummaryProvider =
    FutureProvider<Map<String, List<String>>>((ref) async {
  final rows = await ref.watch(videoRepositoryProvider).loadUnitWordSummary();
  final m = <String, List<String>>{};
  for (final r in rows) {
    final lvl = (r['level'] as num?)?.toInt();
    final unit = (r['unit'] as num?)?.toInt();
    final words = (r['words'] as List?)?.cast<String>() ?? const [];
    if (lvl != null && unit != null) m['L$lvl.u$unit'] = words;
  }
  return m;
});

final curriculumProvider = FutureProvider<List<PathTopic>>((ref) async {
  final vids = await ref.watch(allActiveVideosProvider.future);
  await ref.watch(grammarMetaProvider.future); // ensure metadata is loaded
  final unitWords = await ref.watch(unitWordSummaryProvider.future);
  return buildCurriculum(vids, ref.read(grammarByLevelProvider), unitWords);
});

final pathProgressProvider = FutureProvider<Map<String, dynamic>>((ref) {
  // Re-read when the signed-in uid changes.
  ref.watch(authUidProvider.select((a) => a.valueOrNull));
  return ref.watch(userRepositoryProvider).loadPathProgress();
});

// Which HSK topic the path screen is showing.
final selectedTopicHskProvider = StateProvider<int>((ref) => 1);

// Whether the L1-L6 level list is expanded under "Öğren" in the left nav.
// Collapsed by default; opens when the user taps "Öğren" or presses "BAŞLA".
final learnNavExpandedProvider = StateProvider<bool>((ref) => false);

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

// ── Leagues + friends ─────────────────────────────────────────────────────────
// 12 tiers, bottom-up — the Chinese lunar zodiac animals (生肖), with the
// Dragon as the top (diamond) league. Everyone starts in tier 1; weekly
// 30-user groups, the top 6 promote, the bottom 6 demote (pg_cron job
// 'league-rollover'). Display names come from AppL10n.leagueName(tier).
const int kLeagueCount = 12;
const List<String> kLeagueEmojis = [
  '🐭', '🐮', '🐯', '🐰', '🐍', '🐴',
  '🐐', '🐵', '🐔', '🐶', '🐷', '🐲',
];
const List<Color> kLeagueColors = [
  Color(0xFF8D9B99), Color(0xFFB8C4CC), Color(0xFFE8A33D), Color(0xFF3FB58E),
  Color(0xFF7BC96F), Color(0xFF2EC4B6), Color(0xFF1CB0F6), Color(0xFFCE82FF),
  Color(0xFFE0442C), Color(0xFFD4A33D), Color(0xFFF4ECE0), Color(0xFFFFD700),
];

final leagueGroupProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(authUidProvider.select((a) => a.valueOrNull));
  return ref.watch(userRepositoryProvider).loadLeagueGroup();
});

final friendsLeaderboardProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(authUidProvider.select((a) => a.valueOrNull));
  return ref.watch(userRepositoryProvider).loadFriendsLeaderboard();
});

final diamondsLeaderboardProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(authUidProvider.select((a) => a.valueOrNull));
  return ref.watch(userRepositoryProvider).loadDiamondsLeaderboard();
});
