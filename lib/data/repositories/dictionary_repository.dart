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
      {int limit = 20}) async {
    final data = await _db
        .from('dictionary')
        .select()
        .ilike('simplified', '$query%')
        .limit(limit);
    final results = data.map(DictionaryModel.fromMap).toList();
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
