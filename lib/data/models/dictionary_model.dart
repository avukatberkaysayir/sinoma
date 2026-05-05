import 'package:cloud_firestore/cloud_firestore.dart';

class DictionaryModel {
  final String wordId;
  final String simplified;
  final String traditional;
  final String pinyin;
  final int hskLevel;
  final WordDefinitions definitions;
  final Map<String, AiContextCache> aiContextCache;
  final List<String> radicals;
  final int strokeCount;

  const DictionaryModel({
    required this.wordId,
    required this.simplified,
    required this.traditional,
    required this.pinyin,
    required this.hskLevel,
    required this.definitions,
    this.aiContextCache = const {},
    required this.radicals,
    this.strokeCount = 0,
  });

  factory DictionaryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawCache =
        data['aiContextCache'] as Map<String, dynamic>? ?? {};
    return DictionaryModel(
      wordId: doc.id,
      simplified: data['simplified'] as String? ?? '',
      traditional: data['traditional'] as String? ?? '',
      pinyin: data['pinyin'] as String? ?? '',
      hskLevel: (data['hskLevel'] as num?)?.toInt() ?? 0,
      definitions: WordDefinitions.fromMap(
          data['definitions'] as Map<String, dynamic>? ?? {}),
      aiContextCache: rawCache.map(
        (key, value) =>
            MapEntry(key, AiContextCache.fromMap(value as Map<String, dynamic>)),
      ),
      radicals: List<String>.from(data['radicals'] ?? []),
      strokeCount: (data['strokeCount'] as num?)?.toInt() ?? 0,
    );
  }

  factory DictionaryModel.fromCache(String id, Map<String, dynamic> data) {
    return DictionaryModel(
      wordId: id,
      simplified: data['simplified'] as String? ?? '',
      traditional: data['traditional'] as String? ?? '',
      pinyin: data['pinyin'] as String? ?? '',
      hskLevel: (data['hskLevel'] as num?)?.toInt() ?? 0,
      definitions: WordDefinitions.fromMap(
          data['definitions'] as Map<String, dynamic>? ?? {}),
      aiContextCache: const {},
      radicals: List<String>.from(data['radicals'] ?? []),
      strokeCount: (data['strokeCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'simplified': simplified,
        'traditional': traditional,
        'pinyin': pinyin,
        'hskLevel': hskLevel,
        'definitions': definitions.toMap(),
        'aiContextCache':
            aiContextCache.map((k, v) => MapEntry(k, v.toFirestoreMap())),
        'radicals': radicals,
        'strokeCount': strokeCount,
      };

  // aiContextCache omitted — not JSON-serializable and not needed offline.
  Map<String, dynamic> toCacheMap() => {
        'simplified': simplified,
        'traditional': traditional,
        'pinyin': pinyin,
        'hskLevel': hskLevel,
        'definitions': definitions.toMap(),
        'radicals': radicals,
        'strokeCount': strokeCount,
      };

  bool hasCachedContext(String sentenceHash) =>
      aiContextCache.containsKey(sentenceHash);

  AiContextCache? buildCachedContext(String sentenceHash) =>
      aiContextCache[sentenceHash];

  DictionaryModel copyWithCache(String hash, AiContextCache cache) =>
      DictionaryModel(
        wordId: wordId,
        simplified: simplified,
        traditional: traditional,
        pinyin: pinyin,
        hskLevel: hskLevel,
        definitions: definitions,
        aiContextCache: {...aiContextCache, hash: cache},
        radicals: radicals,
        strokeCount: strokeCount,
      );
}

class WordDefinitions {
  final String tr;
  final String en;
  final String vi;

  const WordDefinitions({
    required this.tr,
    required this.en,
    this.vi = '',
  });

  factory WordDefinitions.fromMap(Map<String, dynamic> map) => WordDefinitions(
        tr: map['tr'] as String? ?? '',
        en: map['en'] as String? ?? '',
        vi: map['vi'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {'tr': tr, 'en': en, 'vi': vi};
}

class AiContextCache {
  final String explanation;
  final String grammarNote;
  final DateTime cachedAt;

  const AiContextCache({
    required this.explanation,
    required this.grammarNote,
    required this.cachedAt,
  });

  factory AiContextCache.fromMap(Map<String, dynamic> map) => AiContextCache(
        explanation: map['explanation'] as String? ?? '',
        grammarNote: map['grammarNote'] as String? ?? '',
        cachedAt: map['cachedAt'] is Timestamp
            ? (map['cachedAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  Map<String, dynamic> toFirestoreMap() => {
        'explanation': explanation,
        'grammarNote': grammarNote,
        'cachedAt': Timestamp.fromDate(cachedAt),
      };
}
