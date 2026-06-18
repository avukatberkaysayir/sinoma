// Single resolver for a landmark's localized name/description across all 12 UI
// languages. TR/EN come from the Landmark constant (cities.dart); the other ten
// from the generated packs (landmarks_<lang>.dart), keyed by '<citySlug>/<icon>'.
// English is the universal fallback when a pack lacks the entry.
import '../cities.dart';
import 'landmarks_ko.dart';
import 'landmarks_ja.dart';
import 'landmarks_id.dart';
import 'landmarks_vi.dart';
import 'landmarks_th.dart';
import 'landmarks_ru.dart';
import 'landmarks_es.dart';
import 'landmarks_pt.dart';
import 'landmarks_fr.dart';
import 'landmarks_ar.dart';

// The UI languages, in editor display order (TR/EN first — the source pair).
const List<String> kLandmarkLangs = [
  'tr', 'en', 'ko', 'ja', 'id', 'vi', 'th', 'ru', 'es', 'pt', 'fr', 'ar'
];

(String, String)? _pack(String lang, String key) => switch (lang) {
      'ko' => kLandmarkKo[key],
      'ja' => kLandmarkJa[key],
      'id' => kLandmarkId[key],
      'vi' => kLandmarkVi[key],
      'th' => kLandmarkTh[key],
      'ru' => kLandmarkRu[key],
      'es' => kLandmarkEs[key],
      'pt' => kLandmarkPt[key],
      'fr' => kLandmarkFr[key],
      'ar' => kLandmarkAr[key],
      _ => null,
    };

String landmarkName(String slug, String icon, String lang, Landmark lm) {
  if (lang == 'tr') return lm.nameTr;
  if (lang == 'en') return lm.nameEn;
  final p = _pack(lang, '$slug/$icon');
  return (p != null && p.$1.isNotEmpty) ? p.$1 : lm.nameEn;
}

String landmarkDesc(String slug, String icon, String lang, Landmark lm) {
  if (lang == 'tr') return lm.descTr;
  if (lang == 'en') return lm.descEn;
  final p = _pack(lang, '$slug/$icon');
  return (p != null && p.$2.isNotEmpty) ? p.$2 : lm.descEn;
}
