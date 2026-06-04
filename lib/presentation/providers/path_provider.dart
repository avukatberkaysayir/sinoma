import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/video_segment_model.dart';
import 'user_provider.dart';
import 'video_provider.dart';

// ── Tuning ────────────────────────────────────────────────────────────────────
const int kPhaseSize = 8; // target videos per phase
const int kPhasesPerStep = 4;
const double kPassRatio = 0.6; // ≥60% correct to clear a phase

// ── Curriculum model ──────────────────────────────────────────────────────────

class PathPhase {
  final int hsk;
  final int stepIndex;
  final int phaseIndex; // within the step (0..3)
  final List<VideoSegmentModel> videos;
  const PathPhase({
    required this.hsk,
    required this.stepIndex,
    required this.phaseIndex,
    required this.videos,
  });

  String get key => 'hsk$hsk.s$stepIndex.p$phaseIndex';
}

class PathStep {
  final int hsk;
  final int index;
  final String title; // predefined Turkish topic title
  final List<PathPhase> phases; // empty → step shown locked ("coming soon")
  const PathStep({
    required this.hsk,
    required this.index,
    required this.title,
    required this.phases,
  });

  bool get hasContent => phases.isNotEmpty;
}

class PathTopic {
  final int hsk;
  final List<PathStep> steps;
  const PathTopic({required this.hsk, required this.steps});
}

// Predefined curriculum: 30 topic (step) titles per HSK level. The whole map is
// always shown (Duolingo-style); steps fill with thematically-matching videos as
// they are approved and lock otherwise.
const Map<int, List<String>> kStepTitles = {
  1: [
    'Selamlaşma', 'Tanışma', 'Kişisel Bilgiler', 'Sayılar 1-10', 'Sayılar 11-100',
    'Aile', 'Meslekler', 'Zaman & Saat', 'Günler & Aylar', 'Yeme & İçme',
    'Meyve & Sebze', 'Renkler', 'Günlük Nesneler', 'Vücut', 'Giysiler',
    'Hava Durumu', 'Günlük Fiiller', 'Yön & Yer', 'Ev & Odalar', 'Okul',
    'Alışveriş', 'Para & Fiyat', 'Ulaşım', 'Hayvanlar', 'Temel Duygular',
    'Temel Sıfatlar', 'Soru Sözcükleri', 'Selam & Veda', 'Tekrar I', 'Tekrar II',
  ],
  2: [
    'Hobiler', 'Boş Zaman', 'Hava & Mevsimler', 'Şehirde Ulaşım', 'Yol Sorma',
    'Sağlık & Vücut', 'Doktora Gitmek', 'Telefonla Konuşma', 'İnternet & Mesaj',
    'İş & Meslek', 'Ofiste', 'Ev İşleri', 'Mobilya & Eşya', 'Duygular',
    'Plan Yapma', 'Randevu', 'Yemek Tarifi', 'Restoranda', 'Spor', 'Egzersiz',
    'Tatil', 'Otelde', 'Kıyafet Alışverişi', 'Markette', 'Komşular',
    'Arkadaşlık', 'Davet', 'Kutlama', 'Tekrar I', 'Tekrar II',
  ],
  3: [
    'Seyahat Planı', 'Havaalanında', 'Otel & Konaklama', 'Restoran Kültürü',
    'Bankada İşlemler', 'Postanede', 'Şehir Hayatı', 'Kırsal Hayat',
    'Doğa & Çevre', 'Hayvanlar & Bitkiler', 'Teknoloji', 'Sosyal Medya',
    'Eğitim & Okul', 'Sınavlar', 'Kültür & Sanat', 'Sinema & Müzik',
    'Sağlıklı Beslenme', 'Hastalıklar', 'İş Görüşmesi', 'Toplantı',
    'Alışkanlıklar', 'Karar Verme', 'Kıyaslama', 'Tavsiye', 'Şikayet',
    'Kutlamalar', 'Gelenekler', 'Anılar', 'Tekrar I', 'Tekrar II',
  ],
  4: [
    'İş Dünyası', 'Kariyer', 'Mülakat', 'Sunum', 'Ekonomi & Para',
    'Haberler', 'Medya', 'Sosyal Konular', 'Bilim & Teknoloji', 'İnternet Çağı',
    'Tarih', 'Coğrafya', 'Edebiyat', 'Sanat & Estetik', 'Çevre Sorunları',
    'İklim & Doğa', 'Sağlık Sistemi', 'Psikoloji', 'Eğitim Politikası',
    'Hukuk & Adalet', 'Suç & Ceza', 'Tartışma', 'İkna', 'Görüş Bildirme',
    'Kültürlerarası', 'Küreselleşme', 'Gelecek', 'Etik', 'Tekrar I', 'Tekrar II',
  ],
  5: [
    'Akademik Dil', 'Araştırma', 'İş Stratejisi', 'Liderlik', 'Politika',
    'Diplomasi', 'Felsefe', 'Mantık', 'Psikoloji İleri', 'Sosyoloji',
    'Sanat Eleştirisi', 'Müzik Teorisi', 'Küresel Ekonomi', 'Finans',
    'Teknoloji & Gelecek', 'Yapay Zeka', 'Edebi Metinler', 'Şiir & Nesir',
    'Resmî Yazışma', 'Rapor Yazma', 'Müzakere', 'Anlaşmazlık Çözümü',
    'Bilimsel Yöntem', 'Tıp & Sağlık', 'Çevre Politikası', 'Sürdürülebilirlik',
    'Tarih Felsefesi', 'Medeniyetler', 'Tekrar I', 'Tekrar II',
  ],
  6: [
    'İleri Akademik', 'Tez & Argüman', 'Deyimler', 'Atasözleri', 'Klasik Metinler',
    'Klasik Şiir', 'Modern Edebiyat', 'Hukuki Dil', 'Sözleşmeler', 'Tıbbi Dil',
    'Bilimsel Makale', 'Felsefi Tartışma', 'Eleştirel Düşünme', 'Köşe Yazısı',
    'Gazetecilik', 'Diplomatik Dil', 'Uluslararası İlişkiler', 'Edebi Çeviri',
    'Üslup & Retorik', 'Mecaz & İmge', 'Kültürel Göndermeler', 'Tarihî Belgeler',
    'Bilim Felsefesi', 'Etik Tartışmalar', 'Sanat Tarihi', 'Estetik Kuram',
    'Söylem Analizi', 'Usta Seviyesi', 'Tekrar I', 'Tekrar II',
  ],
};

// Map a step title to a content theme (a LifeCategory.name) by keyword, so videos
// land in thematically-appropriate steps. Falls back to daily_life.
String _themeForTitle(String title) {
  final t = title.toLowerCase();
  bool has(List<String> ks) => ks.any(t.contains);
  if (has(['aile', 'komşu', 'arkadaş', 'tanış', 'kişisel', 'davet'])) {
    return 'family';
  }
  if (has(['yeme', 'içme', 'meyve', 'sebze', 'yemek', 'restoran', 'tarif', 'beslen', 'market'])) {
    return 'food';
  }
  if (has(['alışveriş', 'para', 'fiyat', 'kıyafet', 'giysi'])) {
    return 'shopping';
  }
  if (has(['seyahat', 'tatil', 'otel', 'ulaşım', 'havaalan', 'yol', 'konaklama', 'coğraf'])) {
    return 'travel';
  }
  if (has(['iş', 'meslek', 'ofis', 'kariyer', 'mülakat', 'görüşme', 'ekonomi', 'finans',
      'toplantı', 'sunum', 'rapor', 'müzakere', 'strateji', 'liderlik', 'sözleşme', 'ticar'])) {
    return 'business';
  }
  if (has(['okul', 'eğitim', 'sınav', 'akademik', 'araştırma', 'ders', 'tez', 'üniversite'])) {
    return 'school';
  }
  if (has(['sağlık', 'doktor', 'hasta', 'vücut', 'tıbb', 'tıp', 'psikoloji', 'egzersiz'])) {
    return 'health';
  }
  if (has(['teknoloji', 'internet', 'bilim', 'yapay zeka', 'medya', 'dijital', 'sosyal medya'])) {
    return 'technology';
  }
  if (has(['sanat', 'müzik', 'sinema', 'film', 'edebi', 'şiir', 'kültür', 'eğlence', 'estetik'])) {
    return 'entertainment';
  }
  if (has(['spor', 'egzersiz', 'futbol', 'oyun'])) {
    return 'sports';
  }
  if (has(['çocuk', 'hayvan', 'renk', 'sayı'])) {
    return 'children';
  }
  return 'daily_life';
}

// Build the full curriculum (HSK 1-6). Every predefined step is created and
// filled with videos whose theme matches the step title (per HSK level), in
// order; steps without matching content stay locked.
List<PathTopic> buildCurriculum(List<VideoSegmentModel> all) {
  final topics = <PathTopic>[];
  for (var hsk = 1; hsk <= 6; hsk++) {
    final titles = kStepTitles[hsk] ?? const [];

    // Group this HSK level's videos by theme into FIFO queues (newest first).
    final byTheme = <String, List<VideoSegmentModel>>{};
    final pool = all.where((v) => v.hskLevelTags.contains(hsk)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final v in pool) {
      final theme = v.lifeTags.isNotEmpty ? v.lifeTags.first : 'daily_life';
      (byTheme[theme] ??= []).add(v);
    }
    final cursors = {for (final k in byTheme.keys) k: 0};

    final steps = <PathStep>[];
    for (var s = 0; s < titles.length; s++) {
      final theme = _themeForTitle(titles[s]);
      final queue = byTheme[theme] ?? const [];
      final cur = cursors[theme] ?? 0;
      const cap = kPhasesPerStep * kPhaseSize;
      final take = (queue.length - cur).clamp(0, cap);
      final stepVideos = queue.sublist(cur, cur + take);
      cursors[theme] = cur + take;

      final phases = <PathPhase>[];
      for (var i = 0; i < stepVideos.length; i += kPhaseSize) {
        phases.add(PathPhase(
          hsk: hsk,
          stepIndex: s,
          phaseIndex: i ~/ kPhaseSize,
          videos: stepVideos.sublist(
              i, (i + kPhaseSize) > stepVideos.length ? stepVideos.length : i + kPhaseSize),
        ));
      }
      steps.add(PathStep(hsk: hsk, index: s, title: titles[s], phases: phases));
    }
    topics.add(PathTopic(hsk: hsk, steps: steps));
  }
  return topics;
}

// ── Progress ──────────────────────────────────────────────────────────────────

class PhaseProgress {
  final int correct;
  final int total;
  final bool done;
  const PhaseProgress(
      {this.correct = 0, this.total = 0, this.done = false});
}

extension PathProgressMap on Map<String, dynamic> {
  PhaseProgress phase(String key) {
    final m = this[key];
    if (m is Map) {
      return PhaseProgress(
        correct: (m['correct'] as int?) ?? 0,
        total: (m['total'] as int?) ?? 0,
        done: m['done'] == true,
      );
    }
    return const PhaseProgress();
  }
}

// A phase is unlocked if it's the first in the topic or the PREVIOUS phase (in
// flat order across steps) is done.
bool isPhaseUnlocked(
    PathTopic topic, PathPhase phase, Map<String, dynamic> progress) {
  final flat = <PathPhase>[for (final s in topic.steps) ...s.phases];
  final idx = flat.indexWhere((p) => p.key == phase.key);
  if (idx <= 0) return true;
  return progress.phase(flat[idx - 1].key).done;
}

// ── Providers ─────────────────────────────────────────────────────────────────

final allActiveVideosProvider = FutureProvider<List<VideoSegmentModel>>((ref) {
  return ref.watch(videoRepositoryProvider).loadAllActiveSegments();
});

final curriculumProvider = FutureProvider<List<PathTopic>>((ref) async {
  final vids = await ref.watch(allActiveVideosProvider.future);
  return buildCurriculum(vids);
});

final pathProgressProvider = FutureProvider<Map<String, dynamic>>((ref) {
  // Re-read when the signed-in uid changes.
  ref.watch(authUidProvider.select((a) => a.valueOrNull));
  return ref.watch(userRepositoryProvider).loadPathProgress();
});

// Which HSK topic the path screen is showing.
final selectedTopicHskProvider = StateProvider<int>((ref) => 1);

// ── Gamification: hearts (lives) + streak ─────────────────────────────────────
const int kMaxHearts = 5;
const Duration kHeartRefill = Duration(hours: 4); // +1 heart every 4h

class PathMeta {
  final int hearts; // live count (refill applied)
  final int streak; // consecutive active days
  final DateTime? nextHeartAt; // when the next heart refills (null if full)
  const PathMeta({this.hearts = kMaxHearts, this.streak = 0, this.nextHeartAt});
}

// Hearts/streak live in path_progress under the "__meta" key:
// {hearts, heartsTs(ISO), streak, lastActive(yyyy-mm-dd)}.
PathMeta computeMeta(Map<String, dynamic> progress) {
  final m = progress['__meta'];
  if (m is! Map) return const PathMeta();
  var hearts = (m['hearts'] as int?) ?? kMaxHearts;
  final ts = DateTime.tryParse((m['heartsTs'] as String?) ?? '');
  DateTime? nextAt;
  if (hearts < kMaxHearts && ts != null) {
    final elapsed = DateTime.now().difference(ts);
    final refills = elapsed.inMinutes ~/ kHeartRefill.inMinutes;
    hearts = (hearts + refills).clamp(0, kMaxHearts);
    if (hearts < kMaxHearts) {
      nextAt = ts.add(kHeartRefill * (refills + 1));
    }
  }
  return PathMeta(
      hearts: hearts, streak: (m['streak'] as int?) ?? 0, nextHeartAt: nextAt);
}

final pathMetaProvider = Provider<PathMeta>((ref) {
  final p = ref.watch(pathProgressProvider).valueOrNull ?? const {};
  return computeMeta(p);
});
