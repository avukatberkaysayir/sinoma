import '../../data/models/dictionary_model.dart';

class TranslationHelper {
  TranslationHelper._();

  static String getDefinition(DictionaryModel word, String languageCode) {
    switch (languageCode) {
      case 'tr':
        return word.definitions.tr;
      case 'ko':
        return word.definitions.ko.isNotEmpty
            ? word.definitions.ko
            : word.definitions.en;
      case 'ja':
        return word.definitions.ja.isNotEmpty
            ? word.definitions.ja
            : word.definitions.en;
      case 'id':
        return word.definitions.id.isNotEmpty
            ? word.definitions.id
            : word.definitions.en;
      case 'th':
        return word.definitions.th.isNotEmpty
            ? word.definitions.th
            : word.definitions.en;
      case 'vi':
        return word.definitions.vi.isNotEmpty
            ? word.definitions.vi
            : word.definitions.en;
      case 'ru':
        return word.definitions.ru.isNotEmpty
            ? word.definitions.ru
            : word.definitions.en;
      case 'es':
        return word.definitions.es.isNotEmpty
            ? word.definitions.es
            : word.definitions.en;
      case 'pt':
        return word.definitions.pt.isNotEmpty
            ? word.definitions.pt
            : word.definitions.en;
      case 'fr':
        return word.definitions.fr.isNotEmpty
            ? word.definitions.fr
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
