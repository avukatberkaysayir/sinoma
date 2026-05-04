import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/dictionary_model.dart';

class DictionaryRepository {
  final FirebaseFirestore _firestore;

  DictionaryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<DictionaryModel?> loadWord(String wordId) async {
    final doc = await _firestore.collection('dictionary').doc(wordId).get();
    if (!doc.exists) return null;
    return DictionaryModel.fromFirestore(doc);
  }

  Future<List<DictionaryModel>> loadWordsForIds(List<String> wordIds) async {
    if (wordIds.isEmpty) return [];
    final futures = wordIds.map(loadWord);
    final results = await Future.wait(futures);
    return results.whereType<DictionaryModel>().toList();
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
    return snap.docs.map(DictionaryModel.fromFirestore).toList();
  }
}
