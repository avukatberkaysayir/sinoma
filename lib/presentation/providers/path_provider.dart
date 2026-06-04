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

// Predefined curriculum: topic (step) titles per HSK level. The whole map is
// always shown (Duolingo-style); steps fill with content as videos are approved
// and lock otherwise. Extend each list toward ~30 steps over time.
const Map<int, List<String>> kStepTitles = {
  1: [
    'Selamlaşma', 'Tanışma', 'Sayılar', 'Aile', 'Zaman & Tarih',
    'Yeme & İçme', 'Renkler & Nesneler', 'Günlük Fiiller', 'Yön & Yer',
    'Alışveriş', 'Okul', 'Vedalaşma',
  ],
  2: [
    'Hobiler', 'Hava Durumu', 'Ulaşım', 'Sağlık', 'Telefon & İletişim',
    'İş & Meslek', 'Ev & Eşya', 'Duygular', 'Plan Yapma', 'Yemek Tarifi',
    'Spor', 'Tatil',
  ],
  3: [
    'Seyahat', 'Restoranda', 'Doktorda', 'Bankada', 'Şehir Hayatı',
    'Doğa & Çevre', 'Teknoloji', 'Eğitim', 'Kültür & Sanat', 'Görüşme',
    'Alışkanlıklar', 'Kutlamalar',
  ],
  4: [
    'İş Görüşmesi', 'Toplantılar', 'Haberler', 'Ekonomi', 'Sosyal Medya',
    'Bilim', 'Tarih', 'Edebiyat', 'Çevre Sorunları', 'Sağlıklı Yaşam',
    'Hukuk', 'Tartışma',
  ],
  5: [
    'Akademik Dil', 'İş Dünyası', 'Politika', 'Felsefe', 'Psikoloji',
    'Sanat Eleştirisi', 'Küresel Konular', 'Teknoloji & Gelecek', 'Edebi Metinler',
    'Resmî Yazışma', 'Sunum', 'Müzakere',
  ],
  6: [
    'İleri Akademik', 'Deyimler & Atasözleri', 'Klasik Metinler', 'Şiir',
    'Hukuki Dil', 'Tıbbi Dil', 'Felsefi Tartışma', 'Köşe Yazısı',
    'Bilimsel Makale', 'Diplomatik Dil', 'Edebi Çeviri', 'Usta Seviyesi',
  ],
};

// Build the full curriculum (HSK 1-6). Every predefined step is created; the
// HSK video pool fills steps' phases in order, the rest stay locked.
List<PathTopic> buildCurriculum(List<VideoSegmentModel> all) {
  final topics = <PathTopic>[];
  for (var hsk = 1; hsk <= 6; hsk++) {
    final titles = kStepTitles[hsk] ?? const [];
    final pool = all.where((v) => v.hskLevelTags.contains(hsk)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Slice the pool into phases of kPhaseSize.
    final phaseChunks = <List<VideoSegmentModel>>[];
    for (var i = 0; i < pool.length; i += kPhaseSize) {
      phaseChunks.add(pool.sublist(
          i, (i + kPhaseSize) > pool.length ? pool.length : i + kPhaseSize));
    }

    var cursor = 0;
    final steps = <PathStep>[];
    for (var s = 0; s < titles.length; s++) {
      final stepPhases = <PathPhase>[];
      for (var p = 0; p < kPhasesPerStep && cursor < phaseChunks.length; p++) {
        stepPhases.add(PathPhase(
            hsk: hsk, stepIndex: s, phaseIndex: p, videos: phaseChunks[cursor++]));
      }
      steps.add(PathStep(hsk: hsk, index: s, title: titles[s], phases: stepPhases));
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
