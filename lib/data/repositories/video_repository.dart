import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/video_segment_model.dart';
import '../services/cache_service.dart';

class VideoRepository {
  final CacheService _cache;

  VideoRepository({required CacheService cache}) : _cache = cache;

  SupabaseClient get _db => Supabase.instance.client;

  // Practice feed: every clip at or below the user's tested HSK level —
  // including backups (yedek), unlike the home/path which is active-only.
  Future<List<VideoSegmentModel>> loadSegmentsForLevel(int hskLevel) async {
    try {
      final data = await _db
          .from('videos')
          .select()
          .lte('hsk_level', hskLevel)
          .inFilter('status', ['active', 'backup'])
          .order('hsk_level')
          .order('created_at', ascending: false)
          .limit(1000);

      final segments = data.map(VideoSegmentModel.fromMap).toList();
      await _cache.cacheVideoFeed(hskLevel, segments);
      return segments;
    } catch (e) {
      final cached = _cache.loadCachedVideoFeed(hskLevel);
      return cached ?? [];
    }
  }

  // All active clips (every HSK level) — the learning path builds its curriculum
  // from this pool by slicing per HSK level + theme.
  Future<List<VideoSegmentModel>> loadAllActiveSegments() async {
    final data = await _db
        .from('videos')
        .select()
        .eq('is_active', true)
        .order('hsk_level')
        .order('created_at', ascending: false)
        .limit(5000);
    return data.map(VideoSegmentModel.fromMap).toList();
  }

  // Vocabulary→slot map for the path: each HSK word is pinned to a (level, unit,
  // phase) so no-grammar clips containing it surface in that circle. Also feeds
  // the "gözat" panel (word + dictionary meaning per slot).
  // Words pinned to one path slot (on demand for the "gözat" panel). Loading the
  // whole table up-front hit PostgREST's 1000-row cap, so higher levels showed
  // empty — fetch per slot instead.
  Future<List<Map<String, dynamic>>> loadWordsForSlot(
      int level, int unit, int phase) async {
    final data = await _db
        .from('path_word_slots')
        .select()
        .eq('level', level)
        .eq('unit', unit)
        .eq('phase', phase)
        .order('word')
        .limit(500);
    return List<Map<String, dynamic>>.from(data);
  }

  // A few representative words per (level, unit) — for the unit caption on units
  // that have no grammar rule (so they show their vocabulary instead of "Soon").
  Future<List<Map<String, dynamic>>> loadUnitWordSummary() async {
    final data = await _db
        .rpc('unit_word_summary')
        .timeout(const Duration(seconds: 8));
    return List<Map<String, dynamic>>.from(data as List);
  }

  // All distinct vocabulary words of one HSK level (word + meaning) — for the
  // per-level word picker in the YouTube import content filter. Paginated, since
  // PostgREST caps a single response at 1000 rows and some levels have more
  // (HSK6 ~2400) — the cap used to silently truncate the list.
  Future<List<Map<String, dynamic>>> loadWordsForLevel(int level) async {
    const page = 1000;
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (var from = 0;; from += page) {
      final data = await _db
          .from('path_word_slots')
          .select('word, tr')
          .eq('level', level)
          .order('word')
          .range(from, from + page - 1)
          .timeout(const Duration(seconds: 12));
      final rows = List<Map<String, dynamic>>.from(data as List);
      for (final r in rows) {
        final w = r['word'] as String? ?? '';
        if (w.isNotEmpty && seen.add(w)) out.add(r);
      }
      if (rows.length < page) break;
    }
    return out;
  }

  // Admin-managed home design overrides for a unit (banner / photos / icons +
  // descriptions + scales). Public read; falls back to bundled assets when empty.
  Future<List<Map<String, dynamic>>> loadPathAssets(int level, int unit) async {
    final data = await _db
        .from('path_assets')
        .select()
        .eq('level', level)
        .eq('unit', unit);
    return List<Map<String, dynamic>>.from(data);
  }

  // Grammar rules / words that already have an ACTIVE clip (slot occupant), so the
  // import filter can flag them red ("already covered, don't pick again").
  Future<({Set<String> grammars, Set<String> words})>
      loadUsedActiveSlots() async {
    final data = await _db
        .from('videos')
        .select('slot_grammar, slot_word')
        .eq('status', 'active');
    final rows = List<Map<String, dynamic>>.from(data as List);
    final g = <String>{};
    final w = <String>{};
    for (final r in rows) {
      final sg = r['slot_grammar'] as String?;
      final sw = r['slot_word'] as String?;
      if (sg != null && sg.isNotEmpty) g.add(sg);
      if (sw != null && sw.isNotEmpty) w.add(sw);
    }
    return (grammars: g, words: w);
  }

  // Grammar curriculum metadata (name, level, unit, label) — the source of truth
  // for the grammar list (the Dart const maps no longer cover the expanded set).
  Future<List<Map<String, dynamic>>> loadGrammarMeta() async {
    final data = await _db
        .from('grammar_levels')
        .select('name, level, unit, symbol, zh, tr, en')
        .order('level')
        .order('unit')
        .limit(2000);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<VideoSegmentModel?> loadSegment(String videoId) async {
    try {
      final data = await _db
          .from('videos')
          .select()
          .eq('id', videoId)
          .maybeSingle();
      if (data == null) return null;
      final segment = VideoSegmentModel.fromMap(data);
      await _cache.cacheVideoSegment(segment);
      return segment;
    } catch (_) {
      return _cache.loadCachedSegment(videoId);
    }
  }

  Future<List<VideoSegmentModel>> loadSegmentsByCategory(
    int hskLevel,
    String quizCategory,
  ) async {
    try {
      final data = await _db
          .from('videos')
          .select()
          .lte('hsk_level', hskLevel + 1)
          .eq('is_active', true)
          .eq('quiz_category', quizCategory)
          .order('hsk_level')
          .order('created_at', ascending: false)
          .limit(20);

      return data.map(VideoSegmentModel.fromMap).toList();
    } catch (_) {
      final all = _cache.loadCachedVideoFeed(hskLevel) ?? [];
      return all.where((v) => v.quizCategory.name == quizCategory).toList();
    }
  }

  Future<List<VideoSegmentModel>> loadSegmentsForGame(int hskLevel,
      {int limit = 10}) async {
    try {
      final data = await _db
          .from('videos')
          .select()
          .eq('hsk_level', hskLevel)
          .eq('is_active', true)
          .limit(limit);

      final segments = data.map(VideoSegmentModel.fromMap).toList()..shuffle();
      return segments;
    } catch (_) {
      final cached = _cache.loadCachedVideoFeed(hskLevel) ?? [];
      return (cached..shuffle()).take(limit).toList();
    }
  }
}
