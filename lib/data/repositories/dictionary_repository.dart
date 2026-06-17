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
                'ko': w.length > 5 ? w[5] : '',
                'ja': w.length > 6 ? w[6] : '',
                'id': w.length > 7 ? w[7] : '',
                'vi': w.length > 8 ? w[8] : '',
                'th': w.length > 9 ? w[9] : '',
                'ru': w.length > 10 ? w[10] : '',
                'es': w.length > 11 ? w[11] : '',
                'pt': w.length > 12 ? w[12] : '',
                'fr': w.length > 13 ? w[13] : '',
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

  // ── Discover panel (Tureng-style) ───────────────────────────────────────────

  // Fire-and-forget popularity signal for "Popüler Aramalar".
  Future<void> logSearch(String query) async {
    try {
      await _db.from('search_log').insert({'query': query.trim()});
    } catch (_) {/* logging must never break the search */}
  }

  Future<List<Map<String, dynamic>>> loadTrendingSearches() async {
    try {
      final data = await _db.rpc('trending_searches');
      return List<Map<String, dynamic>>.from(data as List);
    } catch (_) {
      return const [];
    }
  }

  // Deterministic per-day pick over the whole dictionary (same word for
  // everyone all day, changes at UTC midnight).
  Future<DictionaryModel?> wordOfTheDay() async {
    try {
      final total = await _db.from('dictionary').count();
      if (total == 0) return null;
      final day =
          DateTime.now().toUtc().difference(DateTime.utc(2026)).inDays;
      final off = day % total;
      final data = await _db
          .from('dictionary')
          .select()
          .order('id')
          .range(off, off);
      final rows = List<Map<String, dynamic>>.from(data);
      return rows.isEmpty ? null : DictionaryModel.fromMap(rows.first);
    } catch (_) {
      return null;
    }
  }

  // Criterion words of the newest ACTIVE clips ("Yeni Eklenenler").
  Future<List<String>> newestWords({int limit = 10}) async {
    try {
      final data = await _db
          .from('videos')
          .select('slot_word')
          .eq('status', 'active')
          .not('slot_word', 'is', null)
          .order('created_at', ascending: false)
          .limit(30);
      final out = <String>[];
      for (final r in List<Map<String, dynamic>>.from(data)) {
        final w = r['slot_word'] as String?;
        if (w != null && w.isNotEmpty && !out.contains(w)) out.add(w);
        if (out.length >= limit) break;
      }
      return out;
    } catch (_) {
      return const [];
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
      {int limit = 50, String lang = 'tr'}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final qAscii = _stripAccents(q);
    // Three parallel queries — definition search is scoped to the active locale
    // only, which prevents false positives from the other language's words.
    final responses = await Future.wait([
      _db.from('dictionary').select().ilike('simplified', '$q%').gt('hsk_level', 0).limit(limit),
      _db.from('dictionary').select().ilike('pinyin_ascii', '$qAscii%').gt('hsk_level', 0).limit(limit),
      _db
          .from('dictionary')
          .select()
          .filter('definitions->>$lang', 'ilike', '%$q%')
          .gt('hsk_level', 0)
          .limit(limit),
    ]);

    // Merge and deduplicate by id.
    final seen = <String>{};
    final merged = responses
        .expand((r) => r as List)
        .where((m) => seen.add((m as Map)['id'] as String))
        .cast<Map<String, dynamic>>()
        .toList();

    final qL = q.toLowerCase();
    // Client-side verification scoped to active locale.
    final verified = merged.where((m) {
      final simplified = (m['simplified'] as String? ?? '').toLowerCase();
      final pinyinAscii = (m['pinyin_ascii'] as String? ?? '').toLowerCase();
      final defs = m['definitions'] as Map<String, dynamic>? ?? {};
      final langDef = (defs[lang] as String? ?? '').toLowerCase();
      return simplified.startsWith(qL) ||
             pinyinAscii.startsWith(qAscii) ||
             langDef.contains(qL);
    }).toList();

    final results = verified.map(DictionaryModel.fromMap).toList();

    // Sort by relevance: exact match first, then starts-with, then substring.
    results.sort((a, b) =>
        _relevanceScore(b, qL, qAscii, lang).compareTo(_relevanceScore(a, qL, qAscii, lang)));

    await _cache.cacheWords(results);
    return results;
  }

  // Relevance tiers — higher wins:
  //   7  user typed the Chinese character directly
  //   6  DIRECT TRANSLATION   — entire definition equals query   ("okul" → 学校 def:"okul")
  //   5  SYNONYM              — query is one token among several ("ot"   → 草  def:"çimen, ot")
  //   4  CHINESE PREFIX       — simplified starts with query
  //   3  NEAR SYNONYM         — primary definition token starts with query ("otel" for "ot")
  //   2  PINYIN PREFIX        — accent-stripped pinyin starts with query
  //   1  LOOSE MATCH          — query appears as substring in definition
  static int _relevanceScore(DictionaryModel w, String qL, String qAscii, String lang) {
    final simplified = w.simplified.toLowerCase();
    final pa         = w.pinyinAscii.toLowerCase();
    final langDef    = switch (lang) {
      'en' => w.definitions.en,
      'ko' => w.definitions.ko.isNotEmpty ? w.definitions.ko : w.definitions.en,
      'ja' => w.definitions.ja.isNotEmpty ? w.definitions.ja : w.definitions.en,
      'id' => w.definitions.id.isNotEmpty ? w.definitions.id : w.definitions.en,
      'vi' => w.definitions.vi.isNotEmpty ? w.definitions.vi : w.definitions.en,
      'th' => w.definitions.th.isNotEmpty ? w.definitions.th : w.definitions.en,
      'ru' => w.definitions.ru.isNotEmpty ? w.definitions.ru : w.definitions.en,
      'es' => w.definitions.es.isNotEmpty ? w.definitions.es : w.definitions.en,
      'pt' => w.definitions.pt.isNotEmpty ? w.definitions.pt : w.definitions.en,
      'fr' => w.definitions.fr.isNotEmpty ? w.definitions.fr : w.definitions.en,
      _    => w.definitions.tr,
    }.toLowerCase();

    final tokens = langDef
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (simplified == qL)                                          return 7;
    if (langDef == qL)                                             return 6;
    if (tokens.any((t) => t == qL))                               return 5;
    if (simplified.startsWith(qL))                                 return 4;
    if (tokens.isNotEmpty && tokens.first.startsWith(qL))         return 3;
    if (pa.startsWith(qAscii))                                     return 2;
    return 1;
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

  Future<void> suggestWord(String word) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('login_required');
    // Stored as a regular 'text' post with is_word_suggestion flag in metadata.
    // The posts table allows authenticated INSERT and admin can SELECT/DELETE
    // via the RLS policy that includes the admin's email.
    await _db.from('posts').insert({
      'author_id': user.id,
      'content': word.trim(),
      'post_type': 'text',
      'likes': [],
      'metadata': {
        'is_word_suggestion': true,
        'word': word.trim(),
        'suggested_by_uid': user.id,
        'suggested_by_email': user.email ?? '',
      },
    });
  }
}
