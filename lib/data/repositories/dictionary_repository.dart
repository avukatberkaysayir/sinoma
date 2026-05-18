import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/hsk1_words.dart';
import '../models/dictionary_model.dart';
import '../services/cache_service.dart';

class DictionaryRepository {
  final CacheService _cache;

  DictionaryRepository({required CacheService cache}) : _cache = cache;

  SupabaseClient get _db => Supabase.instance.client;

  // Seeds HSK1 words only when the admin (berkaysayir@gmail.com) is logged in
  // and the table has fewer than 150 rows. Idempotent upsert — safe to call
  // multiple times.
  Future<void> ensureHsk1Seeded() async {
    try {
      final user = _db.auth.currentUser;
      if (user == null) return;

      // Check count — skip if already sufficiently populated
      final probe = await _db
          .from('dictionary')
          .select('id')
          .limit(150);
      if ((probe as List).length >= 150) return;

      const batchSize = 50;
      for (var i = 0; i < kHsk1Words.length; i += batchSize) {
        final batch = kHsk1Words.sublist(
            i, (i + batchSize).clamp(0, kHsk1Words.length));
        final rows = batch.map((w) => {
              'id': w[0],
              'simplified': w[0],
              'traditional': w[0],
              'pinyin': w[1],
              'hsk_level': 1,
              'definitions': {
                'en': w[3],
                'tr': w[4],
                'vi': '',
                'pos': w[2],
              },
              'ai_context_cache': <String, dynamic>{},
              'radicals': <String>[],
              'stroke_count': 0,
            }).toList();
        await _db.from('dictionary').upsert(rows, onConflict: 'id');
      }
    } catch (e) {
      debugPrint('DictionaryRepository.ensureHsk1Seeded: $e');
    }
  }

  Future<DictionaryModel?> loadWord(String wordId) async {
    try {
      final data = await _db
          .from('dictionary')
          .select()
          .eq('id', wordId)
          .maybeSingle();
      if (data == null) return null;
      final model = DictionaryModel.fromMap(data);
      await _cache.cacheWord(model);
      return model;
    } catch (_) {
      return _cache.loadCachedWord(wordId);
    }
  }

  Future<List<DictionaryModel>> loadWordsForIds(List<String> wordIds) async {
    if (wordIds.isEmpty) return [];
    try {
      final futures = wordIds.map(loadWord);
      final results = await Future.wait(futures);
      return results.whereType<DictionaryModel>().toList();
    } catch (_) {
      return _cache.loadCachedWordsForIds(wordIds);
    }
  }

  Future<void> saveAiContextCache(
    String wordId,
    String sentenceHash,
    AiContextCache cache,
  ) async {
    final current = await _db
        .from('dictionary')
        .select('ai_context_cache')
        .eq('id', wordId)
        .maybeSingle();
    if (current == null) return;
    final cacheMap = Map<String, dynamic>.from(
        current['ai_context_cache'] as Map<String, dynamic>? ?? {});
    cacheMap[sentenceHash] = cache.toMap();
    await _db
        .from('dictionary')
        .update({'ai_context_cache': cacheMap})
        .eq('id', wordId);
  }

  Future<List<DictionaryModel>> searchWords(String query,
      {int limit = 50}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    // Run all searches in parallel:
    //   simplified & pinyin → starts-with (user types the character/romanization)
    //   definitions.en & .tr → contains (user types part of a definition)
    final responses = await Future.wait([
      _db.from('dictionary').select().ilike('simplified', '$q%').limit(limit),
      _db.from('dictionary').select().ilike('pinyin', '$q%').limit(limit),
      _db
          .from('dictionary')
          .select()
          .filter('definitions->>en', 'ilike', '%$q%')
          .limit(limit),
      _db
          .from('dictionary')
          .select()
          .filter('definitions->>tr', 'ilike', '%$q%')
          .limit(limit),
    ]);

    // Merge and deduplicate by id.
    final seen = <String>{};
    final merged = responses
        .expand((r) => r as List)
        .where((m) => seen.add((m as Map)['id'] as String))
        .cast<Map<String, dynamic>>()
        .toList();

    final results = merged.map(DictionaryModel.fromMap).toList();

    const posOrder = <String, int>{
      'verb': 0,
      'noun': 1,
      'adjective': 2,
      'adverb': 3,
      'pronoun': 4,
      'number': 5,
      'classifier': 6,
      'auxiliary': 7,
      'prefix': 8,
      'suffix': 9,
      'conjunction': 10,
      'preposition': 11,
      'interjection': 12,
      'expression': 13,
    };
    results.sort((a, b) {
      final aPos = a.definitions.pos.split(',').first.trim().toLowerCase();
      final bPos = b.definitions.pos.split(',').first.trim().toLowerCase();
      return (posOrder[aPos] ?? 99).compareTo(posOrder[bPos] ?? 99);
    });

    await _cache.cacheWords(results);
    return results;
  }

  Future<List<DictionaryModel>> loadWordsForLevel(
    int hskLevel, {
    int limit = 20,
  }) async {
    final data = await _db
        .from('dictionary')
        .select()
        .eq('hsk_level', hskLevel)
        .limit(limit * 5);

    final words = data
        .map(DictionaryModel.fromMap)
        .where((w) => w.simplified.length == 1 && w.radicals.isNotEmpty)
        .take(limit)
        .toList()
      ..shuffle();
    await _cache.cacheWords(words);
    return words;
  }
}
