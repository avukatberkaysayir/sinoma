class HskAnalyzer {
  final Map<String, int> _wordLevelMap;

  const HskAnalyzer(this._wordLevelMap);

  /// Highest-level word in the sentence determines the sentence's HSK level.
  int computeSentenceLevel(String sentence) {
    int maxLevel = 1;
    for (final entry in _wordLevelMap.entries) {
      if (sentence.contains(entry.key) && entry.value > maxLevel) {
        maxLevel = entry.value;
      }
    }
    return maxLevel;
  }

  int? lookupWordLevel(String word) => _wordLevelMap[word];

  bool wordExistsInLevel(String word, int targetLevel) =>
      _wordLevelMap[word] == targetLevel;

  List<String> extractWordsAtLevel(String sentence, int level) {
    return _wordLevelMap.entries
        .where((e) => e.value == level && sentence.contains(e.key))
        .map((e) => e.key)
        .toList();
  }

  List<String> extractAllKnownWords(String sentence) {
    return _wordLevelMap.keys
        .where((word) => sentence.contains(word))
        .toList();
  }
}
