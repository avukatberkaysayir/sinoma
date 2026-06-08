import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/video_segment_model.dart';
import '../services/cache_service.dart';

class VideoRepository {
  final CacheService _cache;

  VideoRepository({required CacheService cache}) : _cache = cache;

  SupabaseClient get _db => Supabase.instance.client;

  Future<List<VideoSegmentModel>> loadSegmentsForLevel(int hskLevel) async {
    try {
      final data = await _db
          .from('videos')
          .select()
          .lte('hsk_level', hskLevel + 1)
          .eq('is_active', true)
          .order('hsk_level')
          .order('created_at', ascending: false)
          .limit(20);

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
