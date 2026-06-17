import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/translation_helper.dart';
import '../../../data/models/dictionary_model.dart';
import '../../providers/dictionary_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common/word_detail_sheet.dart';

// Transient search state — auto-disposed when screen leaves the tree.
final _dictionarySearchProvider =
    StateNotifierProvider.autoDispose<_SearchNotifier, _SearchState>(
  (ref) => _SearchNotifier(ref.watch(dictionaryRepositoryProvider)),
);

class _SearchState {
  final List<DictionaryModel> results;
  final bool isLoading;
  final String? error;
  const _SearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
  });
  _SearchState copyWith({
    List<DictionaryModel>? results,
    bool? isLoading,
    String? error,
  }) =>
      _SearchState(
        results: results ?? this.results,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class _SearchNotifier extends StateNotifier<_SearchState> {
  final dynamic _repo;
  Timer? _debounce;
  int _seq = 0;

  _SearchNotifier(this._repo) : super(const _SearchState());

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void search(String query, {String lang = 'tr'}) {
    _debounce?.cancel();
    final q = query.trim();
    if (q.isEmpty) {
      _seq++;
      state = const _SearchState();
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(q, lang));
  }

  Future<void> _run(String q, String lang) async {
    final seq = ++_seq;
    try {
      final results = await _repo.searchWords(q, lang: lang);
      if (seq == _seq) state = _SearchState(results: results);
      // Popularity signal for "Popüler Aramalar" — only settled queries
      // (debounced + at least 2 chars or a CJK char), fire-and-forget.
      if (q.length >= 2 || RegExp(r'[一-鿿]').hasMatch(q)) {
        _repo.logSearch(q);
      }
    } catch (e) {
      if (seq == _seq) state = _SearchState(error: e.toString());
    }
  }
}

// ── Discover panel data (Tureng-style) ────────────────────────────────────────

final _wordOfDayProvider =
    FutureProvider.autoDispose<DictionaryModel?>((ref) {
  return ref.watch(dictionaryRepositoryProvider).wordOfTheDay();
});

final _trendingProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(dictionaryRepositoryProvider).loadTrendingSearches();
});

final _newestWordsProvider =
    FutureProvider.autoDispose<List<String>>((ref) {
  return ref.watch(dictionaryRepositoryProvider).newestWords();
});

// Curated chengyu pool — rotates weekly (UTC), same idiom for everyone.
const List<(String, String, String, String, String, String, String, String, String, String, String, String, String, String)> _kIdioms = [
  ('一帆风顺', 'yī fān fēng shùn', 'Her şey yolunda gitsin', 'Smooth sailing', '순풍에 돛 단 듯 순조롭게', '順風満帆', 'Berjalan mulus tanpa hambatan', 'Thuận buồm xuôi gió', 'ราบรื่นทุกอย่าง', 'Всё идёт гладко', 'Todo viento en popa', 'Tudo de vento em popa', 'Tout baigne', 'كل شيء على ما يرام'),
  ('马马虎虎', 'mǎ mǎ hū hū', 'Şöyle böyle', 'So-so / careless', '그저 그렇다 / 대충대충', 'まあまあ / いいかげん', 'Begitu-begitu saja / asal-asalan', 'Tàm tạm / qua loa', 'งั้น ๆ / ขอไปที', 'Так себе / небрежно', 'Más o menos / a la ligera', 'Mais ou menos / pela metade', 'Couci-couça / à la va-vite', 'لا بأس / على نحوٍ متهاون'),
  ('入乡随俗', 'rù xiāng suí sú', "Bulunduğun yerin adetlerine uy", 'When in Rome…', '로마에 가면 로마법을 따르라', '郷に入っては郷に従え', 'Di mana bumi dipijak, di situ langit dijunjung', 'Nhập gia tùy tục', 'เข้าเมืองตาหลิ่วต้องหลิ่วตาตาม', 'В чужой монастырь со своим уставом не ходят', 'Donde fueres, haz lo que vieres', 'Em Roma, faça como os romanos', 'À Rome, fais comme les Romains', 'لكلّ بلدٍ عادات فاتّبعها'),
  ('熟能生巧', 'shú néng shēng qiǎo', 'Pratik mükemmelleştirir', 'Practice makes perfect', '연습이 실력을 만든다', '習うより慣れろ', 'Bisa karena biasa', 'Trăm hay không bằng tay quen', 'ฝึกฝนบ่อย ๆ ย่อมเชี่ยวชาญ', 'Повторение — мать учения', 'La práctica hace al maestro', 'A prática leva à perfeição', 'C\'est en forgeant qu\'on devient forgeron', 'بالممارسة يأتي الإتقان'),
  ('画蛇添足', 'huà shé tiān zú', 'Gereksiz ekleme yapmak', 'Gilding the lily', '쓸데없이 사족을 붙이다', '蛇足', 'Menambahkan yang tak perlu', 'Vẽ rắn thêm chân', 'วาดงูเติมขา (ทำเกินจำเป็น)', 'Делать лишнее (дорисовать змее ноги)', 'Lo que sobra estorba (poner patas a la serpiente)', 'O que é demais sobra (pôr patas na cobra)', 'En faire trop (ajouter des pattes au serpent)', 'الزيادة في الشيء كنقصانه'),
  ('对牛弹琴', 'duì niú tán qín', 'Boşa nefes tüketmek', 'Preaching to deaf ears', '소귀에 경 읽기', '馬の耳に念仏', 'Seperti menasihati orang yang tak mau dengar', 'Đàn gảy tai trâu', 'สีซอให้ควายฟัง', 'Метать бисер перед свиньями', 'Predicar en el desierto', 'Dar pérolas aos porcos', 'Prêcher dans le désert', 'كمن ينفخ في رماد'),
  ('半途而废', 'bàn tú ér fèi', 'Yarı yolda bırakmak', 'Giving up halfway', '중도에 포기하다', '中途半端でやめる', 'Berhenti di tengah jalan', 'Bỏ dở giữa chừng', 'ล้มเลิกกลางคัน', 'Бросить на полпути', 'Dejar las cosas a medias', 'Desistir no meio do caminho', 'Abandonner à mi-chemin', 'التوقّف في منتصف الطريق'),
  ('井底之蛙', 'jǐng dǐ zhī wā', 'Dar görüşlü kimse', 'A frog in a well', '우물 안 개구리', '井の中の蛙', 'Katak dalam tempurung', 'Ếch ngồi đáy giếng', 'กบในกะลาครอบ', 'Лягушка на дне колодца (узкий кругозор)', 'La rana del pozo (de miras estrechas)', 'O sapo no poço (visão limitada)', 'La grenouille au fond du puits (vue étroite)', 'ضفدع في قاع البئر (أفق ضيّق)'),
  ('守株待兔', 'shǒu zhū dài tù', 'Şansa güvenip beklemek', 'Waiting idly for luck', '요행만 바라며 기다리다', '守株待兎 — 棚からぼた餅を待つ', 'Menanti rezeki tanpa berusaha', 'Ôm cây đợi thỏ', 'เฝ้าตอไม้รอกระต่าย (รอโชคลอย ๆ)', 'Ждать у моря погоды', 'Esperar sentado a que llegue la suerte', 'Esperar a sorte de braços cruzados', 'Attendre que tout tombe du ciel', 'انتظار الحظّ دون سعي'),
  ('亡羊补牢', 'wáng yáng bǔ láo', 'Geç olsun güç olmasın', 'Better late than never', '늦었다고 생각할 때가 가장 빠르다', '遅くてもやらないよりまし', 'Lebih baik terlambat daripada tidak sama sekali', 'Mất bò mới lo làm chuồng', 'วัวหายล้อมคอก (สายดีกว่าไม่ทำ)', 'Лучше поздно, чем никогда', 'Más vale tarde que nunca', 'Antes tarde do que nunca', 'Mieux vaut tard que jamais', 'أن تصل متأخّرًا خير من ألّا تصل'),
  ('塞翁失马', 'sài wēng shī mǎ', 'Her işte bir hayır vardır', 'A blessing in disguise', '새옹지마 — 화가 복이 되기도', '人間万事塞翁が馬', 'Ada hikmah di balik musibah', 'Tái ông mất ngựa', 'โชคร้ายอาจกลายเป็นโชคดี', 'Нет худа без добра', 'No hay mal que por bien no venga', 'Há males que vêm para bem', 'À quelque chose malheur est bon', 'ربّ ضارّةٍ نافعة'),
  ('滴水穿石', 'dī shuǐ chuān shí', 'Damlaya damlaya göl olur', 'Constant effort wins', '낙숫물이 바위를 뚫는다', '点滴石を穿つ', 'Sedikit demi sedikit lama-lama menjadi bukit', 'Nước chảy đá mòn', 'น้ำหยดลงหินทุกวันหินยังกร่อน', 'Капля камень точит', 'Gota a gota se perfora la piedra', 'Água mole em pedra dura tanto bate até que fura', 'Goutte à goutte, l\'eau creuse la pierre', 'الماء يحفر الصخر بالقطرة'),
];

class DictionaryScreen extends ConsumerStatefulWidget {
  final String? initialWordId;

  const DictionaryScreen({super.key, this.initialWordId});

  @override
  ConsumerState<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends ConsumerState<DictionaryScreen> {
  final _controller = TextEditingController();
  bool _suggesting = false;
  final Set<String> _suggestedWords = {};

  @override
  void initState() {
    super.initState();
    // Auto-seed HSK1 words on first ever visit if the table is empty.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dictionaryRepositoryProvider).ensureHsk1Seeded();
      final id = widget.initialWordId;
      if (id != null && id != 'search') _openWordDetail(id);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _suggestWord(String word) async {
    if (word.isEmpty) return;
    setState(() => _suggesting = true);
    try {
      await ref.read(dictionaryRepositoryProvider).suggestWord(word);
      if (mounted) setState(() { _suggesting = false; _suggestedWords.add(word); });
    } catch (e) {
      if (mounted) {
        setState(() => _suggesting = false);
        final msg = e.toString().contains('login_required')
            ? AppL10n.of(context).suggestNeedLogin
            : AppL10n.of(context).genericError;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  void _openWordDetail(String wordId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WordDetailSheet(
        wordId: wordId,
        transcription: '',
        hskLevel: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(_dictionarySearchProvider);
    final notifier    = ref.read(_dictionarySearchProvider.notifier);
    final lang        = ref.watch(currentLanguageProvider);

    return Stack(
      children: [
        Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _controller,
                  autofocus: widget.initialWordId == null || widget.initialWordId == 'search',
                  style: TextStyle(color: AppColors.onSurface),
                  decoration: InputDecoration(
                    hintText: AppL10n.fromCode(lang).dictSearchHint,
                    hintStyle: TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 14),
                    prefixIcon: Icon(Icons.search,
                        color: AppColors.onSurfaceMuted, size: 20),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: AppColors.onSurfaceMuted, size: 18),
                            onPressed: () {
                              _controller.clear();
                              notifier.search('', lang: lang);
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) {
                    setState(() {});
                    notifier.search(v, lang: lang);
                  },
                ),
              ),
              Expanded(child: _buildBody(searchState, lang)),
            ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(_SearchState state, String lang) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Text(
          state.error!,
          style: TextStyle(color: AppColors.onSurfaceMuted),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_controller.text.isEmpty) {
      // Tureng-style discover panel: word of the day, idiom of the week,
      // trending searches and the newest clip words — all wired to our own
      // search/HSK infrastructure.
      return _DiscoverPanel(
        lang: lang,
        onSearch: (q) {
          _controller.text = q;
          setState(() {});
          ref.read(_dictionarySearchProvider.notifier).search(q, lang: lang);
        },
      );
    }

    if (state.results.isEmpty) {
      final q = _controller.text.trim();
      final alreadySuggested = _suggestedWords.contains(q);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppL10n.fromCode(lang).noResultsFound,
              style: TextStyle(
                  color: AppColors.onSurfaceMuted, fontSize: 15),
            ),
            const SizedBox(height: 20),
            if (alreadySuggested)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: AppColors.correctAnswer, size: 20),
                  const SizedBox(width: 8),
                  Text(AppL10n.fromCode(lang).suggestedLbl,
                      style: const TextStyle(
                          color: AppColors.correctAnswer, fontSize: 14)),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: _suggesting ? null : () => _suggestWord(q),
                icon: _suggesting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary))
                    : const Icon(Icons.lightbulb_outline, size: 18),
                label: Text(AppL10n.fromCode(lang).suggestThisWord),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: state.results.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: AppColors.surfaceVariant,
        indent: 56,
      ),
      itemBuilder: (context, i) =>
          _WordTile(word: state.results[i], lang: lang, onTap: _openWordDetail),
    );
  }
}

// ── Discover panel (empty search state, Tureng-style) ─────────────────────────

class _DiscoverPanel extends ConsumerWidget {
  final String lang;
  final void Function(String query) onSearch;
  const _DiscoverPanel({
    required this.lang,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.fromCode(lang);
    final trending = ref.watch(_trendingProvider).valueOrNull ?? const [];
    final newest = ref.watch(_newestWordsProvider).valueOrNull ?? const [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (trending.isNotEmpty) ...[
                  _DiscoverCard(
                    title: l10n.trendingNow,
                    accent: const Color(0xFFFF4B4B),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in trending)
                          _SearchChip(
                            label: t['query'] as String? ?? '',
                            onTap: () =>
                                onSearch(t['query'] as String? ?? ''),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (newest.isNotEmpty) ...[
                  _DiscoverCard(
                    title: l10n.newlyAdded,
                    accent: const Color(0xFF22C55E),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final w in newest)
                          _SearchChip(label: w, onTap: () => onSearch(w)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Dictionary right rail (word of the day / idiom / test) ────────────────────
// Lives beside the centre column on /dictionary, top-down like the other
// sections' right rails.

class DictionaryRightRail extends ConsumerWidget {
  const DictionaryRightRail({super.key});

  void _openWord(BuildContext context, String wordId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WordDetailSheet(
        wordId: wordId,
        transcription: '',
        hskLevel: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(currentLanguageProvider);
    final l10n = AppL10n.fromCode(lang);
    final word = ref.watch(_wordOfDayProvider).valueOrNull;
    final week =
        DateTime.now().toUtc().difference(DateTime.utc(2026)).inDays ~/ 7;
    final idiom = _kIdioms[week % _kIdioms.length];

    return Container(
      width: 340,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFF263230))),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DiscoverCard(
              title: l10n.wordOfDay,
              accent: AppColors.primary,
              onTap:
                  word == null ? null : () => _openWord(context, word.wordId),
              child: word == null
                  ? const _CardLoading()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(word.simplified,
                            style: TextStyle(
                                color: AppColors.onSurface,
                                fontSize: 34,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(word.pinyin,
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(
                          word.definitions.forLang(lang),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.onSurfaceMuted, fontSize: 14),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            _DiscoverCard(
              title: l10n.idiomOfWeek,
              accent: const Color(0xFFE0A800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(idiom.$1,
                      style: TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 28,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(idiom.$2,
                      style: const TextStyle(
                          color: Color(0xFFE0A800),
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                      lang == 'tr'
                          ? idiom.$3
                          : (lang == 'ko'
                              ? idiom.$5
                              : (lang == 'ja'
                                  ? idiom.$6
                                  : (lang == 'id'
                                      ? idiom.$7
                                      : (lang == 'vi'
                                          ? idiom.$8
                                          : (lang == 'th'
                                              ? idiom.$9
                                              : (lang == 'ru'
                                                  ? idiom.$10
                                                  : (lang == 'es'
                                                      ? idiom.$11
                                                      : (lang == 'pt'
                                                          ? idiom.$12
                                                          : (lang == 'fr'
                                                              ? idiom.$13
                                                              : (lang == 'ar' ? idiom.$14 : idiom.$4)))))))))),
                      style: TextStyle(
                          color: AppColors.onSurfaceMuted, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => context.push('/hsk-test'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.quiz_rounded,
                          color: AppColors.primary, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.testYourChinese,
                                style: TextStyle(
                                    color: AppColors.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(l10n.testYourChineseSub,
                                style: TextStyle(
                                    color: AppColors.onSurfaceMuted,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverCard extends StatelessWidget {
  final String title;
  final Color accent;
  final Widget child;
  final VoidCallback? onTap;
  const _DiscoverCard({
    required this.title,
    required this.accent,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _CardLoading extends StatelessWidget {
  const _CardLoading();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 60,
        child: Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
}

class _SearchChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SearchChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppColors.onSurfaceMuted.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search,
                  size: 14, color: AppColors.onSurfaceMuted),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: AppColors.onSurface, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordTile extends StatelessWidget {
  final DictionaryModel word;
  final String lang;
  final void Function(String wordId) onTap;

  const _WordTile({required this.word, required this.lang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.forHskLevel(word.hskLevel),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          word.simplified,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Row(
        children: [
          Text(
            word.pinyin,
            style: TextStyle(color: AppColors.onSurface, fontSize: 15),
          ),
          const SizedBox(width: 8),
          if (word.definitions.pos.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.onSurfaceMuted.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                word.definitions.pos.split(',').first.trim(),
                style: TextStyle(
                    color: AppColors.onSurfaceMuted, fontSize: 10),
              ),
            ),
        ],
      ),
      subtitle: _buildDefinitionText(TranslationHelper.getDefinition(word, lang)),
      trailing: word.hskLevel > 0
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:
                    AppColors.forHskLevel(word.hskLevel).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.forHskLevel(word.hskLevel)
                      .withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                AppL10n.of(context).hskLabel(word.hskLevel),
                style: TextStyle(
                  color: AppColors.forHskLevel(word.hskLevel),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      onTap: () => onTap(word.wordId),
    );
  }

  static Widget _buildDefinitionText(String definition) {
    // "1) first meaning 2) second meaning" → two lines
    final match = RegExp(r'^1\)\s*(.+?)\s+2\)\s*(.+)$').firstMatch(definition);
    if (match != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('1) ${match.group(1)!}',
              style: TextStyle(
                  color: AppColors.onSurfaceMuted, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text('2) ${match.group(2)!}',
              style: TextStyle(
                  color: AppColors.onSurfaceMuted, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      );
    }
    return Text(
      definition,
      style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
