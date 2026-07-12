import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/video_segment_model.dart';
import '../services/cache_service.dart';

class VideoRepository {
  final CacheService _cache;

  VideoRepository({required CacheService cache}) : _cache = cache;

  SupabaseClient get _db => Supabase.instance.client;

  // PostgREST caps every request at 1000 rows and the library passed that —
  // a single .limit() silently dropped the newest tail, so fresh clips never
  // reached the feed/curriculum (görüldü 2026-07-12). Page until short page;
  // the id tiebreaker keeps windows stable across requests.
  static const _pageSize = 1000, _maxRows = 10000;

  Future<List<Map<String, dynamic>>> _paged(
      PostgrestTransformBuilder<List<Map<String, dynamic>>> Function() base)
      async {
    final rows = <Map<String, dynamic>>[];
    while (rows.length < _maxRows) {
      final page =
          await base().range(rows.length, rows.length + _pageSize - 1);
      rows.addAll(List<Map<String, dynamic>>.from(page));
      if (page.length < _pageSize) break;
    }
    return rows;
  }

  // Practice feed: every clip at or below the user's tested HSK level —
  // including backups (yedek), unlike the home/path which is active-only.
  Future<List<VideoSegmentModel>> loadSegmentsForLevel(int hskLevel) async {
    try {
      final data = await _paged(() => _db
          .from('videos')
          .select()
          .lte('hsk_level', hskLevel)
          .inFilter('status', ['active', 'backup'])
          .order('hsk_level')
          .order('created_at', ascending: false)
          .order('id'));

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
    final data = await _paged(() => _db
        .from('videos')
        .select()
        .eq('is_active', true)
        .order('hsk_level')
        .order('created_at', ascending: false)
        .order('id'));
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

  // ── Per-user practice ticks (VoScreen-style mastery, 0..5 per video) ────────

  Future<int> loadVideoTicks(String videoId) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return 0;
    try {
      final row = await _db
          .from('video_ticks')
          .select('ticks')
          .eq('uid', uid)
          .eq('video_id', videoId)
          .maybeSingle();
      return (row?['ticks'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> saveVideoTicks(String videoId, int ticks) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _db.from('video_ticks').upsert({
        'uid': uid,
        'video_id': videoId,
        'ticks': ticks.clamp(0, 5),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'uid,video_id');
    } catch (_) {/* ticks are cosmetic — never block the answer flow */}
  }

  // "Sorun Bildir" — a user-written note about one clip (admin reviews them).
  Future<void> reportVideo(String videoId, String message) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    await _db.from('video_reports').insert({
      'uid': uid,
      'video_id': videoId,
      'message': message.trim(),
    });
  }

  // ── User playlists ──────────────────────────────────────────────────────────

  // Playlists with their clip counts ('count' int per row).
  Future<List<Map<String, dynamic>>> loadPlaylists() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return const [];
    final data = await _db
        .from('playlists')
        .select('id, name, playlist_items(count)')
        .eq('uid', uid)
        .order('created_at');
    return List<Map<String, dynamic>>.from(data).map((r) {
      final items = r['playlist_items'];
      final count = (items is List && items.isNotEmpty)
          ? ((items.first as Map)['count'] as num?)?.toInt() ?? 0
          : 0;
      return {'id': r['id'], 'name': r['name'], 'count': count};
    }).toList();
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _db.from('playlists').delete().eq('id', playlistId);
  }

  // ── Daily answer stats + global rank (profile page) ─────────────────────────

  Future<void> bumpAnswerStat(bool correct, {int points = 0}) async {
    if (_db.auth.currentUser == null) return;
    try {
      await _db.rpc('bump_answer_stat',
          params: {'p_correct': correct, 'p_points': points});
    } catch (_) {/* stats are best-effort */}
  }

  // Watch-time for the badge ladder: the player flushes accumulated playing
  // seconds in small chunks (the RPC caps one bump at 10 min as sanity).
  Future<void> bumpWatchSeconds(int seconds) async {
    if (_db.auth.currentUser == null || seconds <= 0) return;
    try {
      await _db.rpc('bump_watch_seconds', params: {'p_seconds': seconds});
    } catch (_) {/* stats are best-effort */}
  }

  // Lifetime sums across answer_stats: total answers, correct, points,
  // watch seconds — drives the badge (rozet) thresholds.
  Future<Map<String, int>> loadLifetimeStats() async {
    if (_db.auth.currentUser == null) return const {};
    try {
      final r = await _db.rpc('lifetime_stats');
      final row = (r as List).isNotEmpty
          ? Map<String, dynamic>.from(r.first as Map)
          : const <String, dynamic>{};
      return {
        'total': (row['total'] as num?)?.toInt() ?? 0,
        'correct': (row['correct'] as num?)?.toInt() ?? 0,
        'points': (row['points'] as num?)?.toInt() ?? 0,
        'watch_seconds': (row['watch_seconds'] as num?)?.toInt() ?? 0,
      };
    } catch (_) {
      return const {};
    }
  }

  Future<List<Map<String, dynamic>>> loadDailyStats() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return const [];
    final data = await _db
        .from('answer_stats')
        .select('day, total, correct, points')
        .eq('uid', uid)
        .order('day', ascending: false)
        .limit(14);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<int?> loadUserRank() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final r = await _db.rpc('user_rank', params: {'p_uid': uid});
      return (r as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  Future<String?> createPlaylist(String name) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _db
        .from('playlists')
        .insert({'uid': uid, 'name': name.trim()})
        .select('id')
        .single();
    return row['id'] as String?;
  }

  // Which of MY playlists already contain this video.
  Future<Set<String>> playlistsContaining(String videoId) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return const {};
    final data = await _db
        .from('playlist_items')
        .select('playlist_id')
        .eq('uid', uid)
        .eq('video_id', videoId);
    return List<Map<String, dynamic>>.from(data)
        .map((r) => r['playlist_id'] as String)
        .toSet();
  }

  Future<void> addToPlaylist(String playlistId, String videoId) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    await _db.from('playlist_items').upsert({
      'playlist_id': playlistId,
      'video_id': videoId,
      'uid': uid,
    }, onConflict: 'playlist_id,video_id');
  }

  Future<void> removeFromPlaylist(String playlistId, String videoId) async {
    await _db
        .from('playlist_items')
        .delete()
        .eq('playlist_id', playlistId)
        .eq('video_id', videoId);
  }

  // Lightweight rows for the right-rail playlist preview (thumb via youtube_id).
  Future<List<Map<String, dynamic>>> loadPlaylistVideos(
      String playlistId) async {
    final ids = await loadPlaylistVideoIds(playlistId);
    if (ids.isEmpty) return const [];
    final data = await _db
        .from('videos')
        .select('id, transcription, hsk_level, youtube_id')
        .inFilter('id', ids.toList());
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Set<String>> loadPlaylistVideoIds(String playlistId) async {
    final data = await _db
        .from('playlist_items')
        .select('video_id')
        .eq('playlist_id', playlistId);
    return List<Map<String, dynamic>>.from(data)
        .map((r) => r['video_id'] as String)
        .toSet();
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
