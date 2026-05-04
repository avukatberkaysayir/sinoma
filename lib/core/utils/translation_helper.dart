import '../../data/models/dictionary_model.dart';

class TranslationHelper {
  TranslationHelper._();

  static String getDefinition(DictionaryModel word, String languageCode) {
    switch (languageCode) {
      case 'tr':
        return word.definitions.tr;
      case 'vi':
        return word.definitions.vi.isNotEmpty
            ? word.definitions.vi
            : word.definitions.en;
      case 'en':
      default:
        return word.definitions.en;
    }
  }

  static String getPrimaryDefinition(DictionaryModel word, Locale locale) =>
      getDefinition(word, locale.languageCode);
}

// Thin wrapper to avoid importing dart:ui directly in non-widget code.
class Locale {
  final String languageCode;
  const Locale(this.languageCode);
}
