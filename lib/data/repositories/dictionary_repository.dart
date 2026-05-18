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

      final probe = await _db.from('dictionary').select('id').limit(150);
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
              'pinyin_ascii': _stripAccents(w[1]),
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

  // Maps accented pinyin vowels to their plain ASCII equivalents.
  static String _stripAccents(String pinyin) {
    const accentMap = {
      'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a',
      'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e',
      'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i',
      'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o',
      'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u',
      'ǖ': 'v', 'ǘ': 'v', 'ǚ': 'v', 'ǜ': 'v', 'ü': 'v',
    };
    var result = pinyin.toLowerCase();
    for (final entry in accentMap.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
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

    final qAscii = _stripAccents(q);
    // Run all searches in parallel:
    //   simplified → starts-with Chinese character
    //   pinyin_ascii → starts-with accent-stripped romanization (hao → hǎo)
    //   definitions.en & .tr → contains (user types part of a definition)
    final responses = await Future.wait([
      _db.from('dictionary').select().ilike('simplified', '$q%').limit(limit),
      _db.from('dictionary').select().ilike('pinyin_ascii', '$qAscii%').limit(limit),
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

  // Finds Chinese characters whose TR or EN definition contains [query] as a
  // whole comma-separated token. Returns a map of simplified → relevance score:
  //   3 = the entire definition is just the query word (exact match)
  //   2 = query is the first/primary token ("word, ...")
  //   1 = query is a secondary token ("..., word" or "..., word, ...")
  // Uses targeted ILIKE patterns so "ot" never matches "otobüs" or "otel".
  Future<Map<String, int>> findCharsForDefinitionToken(String query) async {
    final q = query.toLowerCase();
    final responses = await Future.wait([
      _db.from('dictionary').select('simplified').filter('definitions->>tr', 'eq',    q       ).limit(30),
      _db.from('dictionary').select('simplified').filter('definitions->>en', 'eq',    q       ).limit(30),
      _db.from('dictionary').select('simplified').filter('definitions->>tr', 'ilike', '$q, %' ).limit(30),
      _db.from('dictionary').select('simplified').filter('definitions->>en', 'ilike', '$q, %' ).limit(30),
      _db.from('dictionary').select('simplified').filter('definitions->>tr', 'ilike', '%, $q' ).limit(30),
      _db.from('dictionary').select('simplified').filter('definitions->>en', 'ilike', '%, $q' ).limit(30),
      _db.from('dictionary').select('simplified').filter('definitions->>tr', 'ilike', '%, $q, %').limit(30),
      _db.from('dictionary').select('simplified').filter('definitions->>en', 'ilike', '%, $q, %').limit(30),
    ]);

    final scores = <String, int>{};
    void add(dynamic rows, int score) {
      for (final row in rows as List) {
        final s = (row as Map<String, dynamic>)['simplified'] as String? ?? '';
        if (s.isNotEmpty && (scores[s] ?? 0) < score) scores[s] = score;
      }
    }

    add(responses[0], 3); add(responses[1], 3); // exact
    add(responses[2], 2); add(responses[3], 2); // primary
    add(responses[4], 1); add(responses[5], 1); // secondary end
    add(responses[6], 1); add(responses[7], 1); // secondary middle
    return scores;
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
