class CharacterAnalyzer {
  final Map<String, List<String>> _radicalMap;

  const CharacterAnalyzer(this._radicalMap);

  List<String> buildRadicalList(String character) =>
      _radicalMap[character] ?? [];

  bool hasRadicals(String character) => _radicalMap.containsKey(character);

  List<String> buildDecoyRadicals(String character, int count) {
    final correct = buildRadicalList(character).toSet();
    final decoys = <String>[];

    for (final entry in _radicalMap.entries) {
      if (decoys.length >= count) break;
      for (final radical in entry.value) {
        if (!correct.contains(radical) && !decoys.contains(radical)) {
          decoys.add(radical);
          break;
        }
      }
    }
    return decoys;
  }

  List<String> buildShuffledTiles(String character, int decoyCount) {
    final correct = buildRadicalList(character);
    final decoys = buildDecoyRadicals(character, decoyCount);
    final all = [...correct, ...decoys]..shuffle();
    return all;
  }
}
