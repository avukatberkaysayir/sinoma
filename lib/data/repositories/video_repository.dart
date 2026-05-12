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
