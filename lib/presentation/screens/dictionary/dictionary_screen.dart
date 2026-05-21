import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/translation_helper.dart';
import '../../../data/models/dictionary_model.dart';
import '../../providers/dictionary_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common/section_sidebar.dart';
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
    } catch (e) {
      if (seq == _seq) state = _SearchState(error: e.toString());
    }
  }
}

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
            ? 'Öneri yapmak için giriş yapınız'
            : 'Bir hata oluştu';
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
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _controller,
                  autofocus: widget.initialWordId == null || widget.initialWordId == 'search',
                  style: const TextStyle(color: AppColors.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search Chinese characters…',
                    hintStyle: const TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 14),
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.onSurfaceMuted, size: 20),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
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
        const SectionSidebarOverlay(current: AppSection.dictionary),
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
          style: const TextStyle(color: AppColors.onSurfaceMuted),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_controller.text.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.translate, color: AppColors.onSurfaceMuted, size: 48),
            SizedBox(height: 16),
            Text(
              'Type a character or word to search',
              style:
                  TextStyle(color: AppColors.onSurfaceMuted, fontSize: 15),
            ),
          ],
        ),
      );
    }

    if (state.results.isEmpty) {
      final q = _controller.text.trim();
      final alreadySuggested = _suggestedWords.contains(q);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No results found',
              style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 15),
            ),
            const SizedBox(height: 20),
            if (alreadySuggested)
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      color: AppColors.correctAnswer, size: 20),
                  SizedBox(width: 8),
                  Text('Önerildi',
                      style: TextStyle(
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
                label: const Text('Bu kelimeyi öner'),
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
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        color: AppColors.surfaceVariant,
        indent: 56,
      ),
      itemBuilder: (context, i) =>
          _WordTile(word: state.results[i], lang: lang, onTap: _openWordDetail),
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
            style: const TextStyle(color: AppColors.onSurface, fontSize: 15),
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
                style: const TextStyle(
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
                'HSK ${word.hskLevel}',
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
              style: const TextStyle(
                  color: AppColors.onSurfaceMuted, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text('2) ${match.group(2)!}',
              style: const TextStyle(
                  color: AppColors.onSurfaceMuted, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      );
    }
    return Text(
      definition,
      style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
