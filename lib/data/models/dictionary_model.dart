class DictionaryModel {
  final String wordId;
  final String simplified;
  final String traditional;
  final String pinyin;
  final String pinyinAscii;
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
    this.pinyinAscii = '',
    required this.hskLevel,
    required this.definitions,
    this.aiContextCache = const {},
    required this.radicals,
    this.strokeCount = 0,
  });

  factory DictionaryModel.fromMap(Map<String, dynamic> data) {
    final rawCache = data['ai_context_cache'] as Map<String, dynamic>? ?? {};
    return DictionaryModel(
      wordId: data['id'] as String? ?? '',
      simplified: data['simplified'] as String? ?? '',
      traditional: data['traditional'] as String? ?? '',
      pinyin: data['pinyin'] as String? ?? '',
      pinyinAscii: data['pinyin_ascii'] as String? ?? '',
      hskLevel: (data['hsk_level'] as num?)?.toInt() ?? 0,
      definitions: WordDefinitions.fromMap(
          data['definitions'] as Map<String, dynamic>? ?? {}),
      aiContextCache: rawCache.map(
        (key, value) =>
            MapEntry(key, AiContextCache.fromMap(value as Map<String, dynamic>)),
      ),
      radicals: List<String>.from(data['radicals'] ?? []),
      strokeCount: (data['stroke_count'] as num?)?.toInt() ?? 0,
    );
  }

  factory DictionaryModel.fromCache(String id, Map<String, dynamic> data) =>
      DictionaryModel(
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

  Map<String, dynamic> toMap() => {
        'id': wordId,
        'simplified': simplified,
        'traditional': traditional,
        'pinyin': pinyin,
        'pinyin_ascii': pinyinAscii,
        'hsk_level': hskLevel,
        'definitions': definitions.toMap(),
        'ai_context_cache':
            aiContextCache.map((k, v) => MapEntry(k, v.toMap())),
        'radicals': radicals,
        'stroke_count': strokeCount,
      };

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
        pinyinAscii: pinyinAscii,
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
  final String ko;
  final String ja;
  final String id;
  final String vi;
  final String th;
  final String ru;
  final String es;
  final String pt;
  final String fr;
  final String pos; // part of speech, stored in definitions JSONB as 'pos' key

  const WordDefinitions({
    required this.tr,
    required this.en,
    this.ko = '',
    this.ja = '',
    this.id = '',
    this.vi = '',
    this.th = '',
    this.ru = '',
    this.es = '',
    this.pt = '',
    this.fr = '',
    this.pos = '',
  });

  factory WordDefinitions.fromMap(Map<String, dynamic> map) => WordDefinitions(
        tr: map['tr'] as String? ?? '',
        en: map['en'] as String? ?? '',
        ko: map['ko'] as String? ?? '',
        ja: map['ja'] as String? ?? '',
        id: map['id'] as String? ?? '',
        vi: map['vi'] as String? ?? '',
        th: map['th'] as String? ?? '',
        ru: map['ru'] as String? ?? '',
        es: map['es'] as String? ?? '',
        pt: map['pt'] as String? ?? '',
        fr: map['fr'] as String? ?? '',
        pos: map['pos'] as String? ?? '',
      );

  // UI display: requested language, English as the universal fallback.
  String forLang(String lang) => switch (lang) {
        'tr' => tr.isNotEmpty ? tr : en,
        'ko' => ko.isNotEmpty ? ko : en,
        'ja' => ja.isNotEmpty ? ja : en,
        'id' => id.isNotEmpty ? id : en,
        'vi' => vi.isNotEmpty ? vi : en,
        'th' => th.isNotEmpty ? th : en,
        'ru' => ru.isNotEmpty ? ru : en,
        'es' => es.isNotEmpty ? es : en,
        'pt' => pt.isNotEmpty ? pt : en,
        'fr' => fr.isNotEmpty ? fr : en,
        _ => en,
      };

  Map<String, dynamic> toMap() =>
      {'tr': tr, 'en': en, 'ko': ko, 'ja': ja, 'id': id, 'vi': vi, 'th': th, 'ru': ru, 'es': es, 'pt': pt, 'fr': fr, 'pos': pos};
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
        cachedAt: map['cachedAt'] != null
            ? DateTime.tryParse(map['cachedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'explanation': explanation,
        'grammarNote': grammarNote,
        'cachedAt': cachedAt.toIso8601String(),
      };
}
