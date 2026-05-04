class HskConstants {
  HskConstants._();

  static const int minLevel = 1;
  static const int maxLevel = 6;

  static const Map<int, int> wordCountPerLevel = {
    1: 150,
    2: 150,
    3: 300,
    4: 600,
    5: 1300,
    6: 2500,
  };

  static const Map<int, String> levelLabels = {
    1: 'HSK 1 — Beginner',
    2: 'HSK 2 — Elementary',
    3: 'HSK 3 — Intermediate',
    4: 'HSK 4 — Upper Intermediate',
    5: 'HSK 5 — Advanced',
    6: 'HSK 6 — Mastery',
  };

  static bool isValidLevel(int level) => level >= minLevel && level <= maxLevel;

  static int computeStretchLevel(int userLevel) =>
      (userLevel + 1).clamp(minLevel, maxLevel);
}
