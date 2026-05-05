import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/dictionary_model.dart';
import '../services/cache_service.dart';

class DictionaryRepository {
  final FirebaseFirestore _firestore;
  final CacheService _cache;

  DictionaryRepository({FirebaseFirestore? firestore, required CacheService cache})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _cache = cache;

  Future<DictionaryModel?> loadWord(String wordId) async {
    try {
      final doc = await _firestore.collection('dictionary').doc(wordId).get();
      if (!doc.exists) return null;
      final model = DictionaryModel.fromFirestore(doc);
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
    await _firestore.collection('dictionary').doc(wordId).update({
      'aiContextCache.$sentenceHash': cache.toFirestoreMap(),
    });
  }

  Future<List<DictionaryModel>> searchWords(String query,
      {int limit = 20}) async {
    final snap = await _firestore
        .collection('dictionary')
        .where('simplified', isGreaterThanOrEqualTo: query)
        .where('simplified', isLessThan: '${query}z')
        .limit(limit)
        .get();
    final results = snap.docs.map(DictionaryModel.fromFirestore).toList();
    await _cache.cacheWords(results);
    return results;
  }

  Future<List<DictionaryModel>> loadWordsForLevel(
    int hskLevel, {
    int limit = 20,
  }) async {
    final snap = await _firestore
        .collection('dictionary')
        .where('hskLevel', isEqualTo: hskLevel)
        .limit(limit * 3)
        .get();

    final words = snap.docs
        .map(DictionaryModel.fromFirestore)
        .where((w) => w.simplified.length == 1 && w.radicals.isNotEmpty)
        .take(limit)
        .toList()
      ..shuffle();
    await _cache.cacheWords(words);
    return words;
  }
}
