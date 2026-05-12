import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dictionary_model.dart';
import '../services/cache_service.dart';

class DictionaryRepository {
  final CacheService _cache;

  DictionaryRepository({required CacheService cache}) : _cache = cache;

  SupabaseClient get _db => Supabase.instance.client;

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

    final data = await _db
        .from('dictionary')
        .select()
        .or('simplified.ilike.$q%,pinyin.ilike.$q%')
        .limit(limit);
    final results = data.map(DictionaryModel.fromMap).toList();

    const posOrder = <String, int>{
      'verb': 0, 'noun': 1, 'adjective': 2, 'adverb': 3,
      'pronoun': 4, 'number': 5, 'classifier': 6, 'auxiliary': 7,
      'prefix': 8, 'suffix': 9, 'conjunction': 10, 'preposition': 11,
      'interjection': 12, 'expression': 13,
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
