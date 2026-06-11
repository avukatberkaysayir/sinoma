import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/sentence_hash.dart';
import '../../../core/utils/translation_helper.dart';
import '../../../data/models/dictionary_model.dart';
import '../../providers/ai_provider.dart';
import '../../providers/credit_provider.dart';
import '../../providers/dictionary_provider.dart';
import '../../providers/user_provider.dart';
import '../ads/reward_ad_widget.dart';

enum _AiStatus { idle, loading, cached, fresh, error }

class WordDetailSheet extends ConsumerStatefulWidget {
  final String wordId;
  final String transcription;
  final int hskLevel;

  const WordDetailSheet({
    super.key,
    required this.wordId,
    required this.transcription,
    required this.hskLevel,
  });

  @override
  ConsumerState<WordDetailSheet> createState() => _WordDetailSheetState();
}

class _WordDetailSheetState extends ConsumerState<WordDetailSheet> {
  DictionaryModel? _word;
  bool _wordLoading = true;

  _AiStatus _aiStatus = _AiStatus.idle;
  AiContextCache? _aiResult;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _loadWord();
  }

  Future<void> _loadWord() async {
    final word =
        await ref.read(dictionaryRepositoryProvider).loadWord(widget.wordId);
    if (!mounted) return;

    // Auto-surface cache entry if it exists — free, no credit consumed.
    AiContextCache? cached;
    if (word != null) {
      final hash =
          SentenceHash.buildAiCacheKey(widget.wordId, widget.transcription);
      cached = word.aiContextCache[hash];
    }

    setState(() {
      _word = word;
      _wordLoading = false;
      if (cached != null) {
        _aiStatus = _AiStatus.cached;
        _aiResult = cached;
      }
    });
  }

  Future<void> _requestExplanation() async {
    if (!AppConfig.hasGeminiKey) {
      setState(() {
        _aiStatus = _AiStatus.error;
        _aiError =
            'Gemini API key not configured. Run with --dart-define=GEMINI_API_KEY=...';
      });
      return;
    }

    setState(() {
      _aiStatus = _AiStatus.loading;
      _aiError = null;
    });

    final word = _word!;
    final lang = ref.read(currentLanguageProvider);

    try {
      // Call Gemini first; decrement credit only on success to preserve UX.
      final result = await ref.read(geminiServiceProvider).explainWordInContext(
            simplified: word.simplified,
            transcription: widget.transcription,
            hskLevel: word.hskLevel,
            userLanguage: lang,
          );

      // Decrement credit via Cloud Function (server-side validation).
      await ref.read(creditServiceProvider).spendOneCredit();

      // Persist cache to Firestore so future opens are free.
      final hash =
          SentenceHash.buildAiCacheKey(widget.wordId, widget.transcription);
      await ref
          .read(dictionaryRepositoryProvider)
          .saveAiContextCache(widget.wordId, hash, result);

      if (!mounted) return;
      setState(() {
        _aiStatus = _AiStatus.fresh;
        _aiResult = result;
      });
    } on AiQuotaExceededException {
      if (!mounted) return;
      // Quota hit between check and spend — reset to idle so credit UI refreshes.
      setState(() => _aiStatus = _AiStatus.idle);
    } on GeminiApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _aiStatus = _AiStatus.error;
        _aiError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiStatus = _AiStatus.error;
        _aiError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canUseAi = ref.watch(canUseAiProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _wordLoading
            ? const Center(child: CircularProgressIndicator())
            : _word == null
                ? const Center(
                    child: Text(
                      'Word not found',
                      style: TextStyle(color: AppColors.onSurface),
                    ),
                  )
                : _buildContent(controller, canUseAi),
      ),
    );
  }

  Widget _buildContent(ScrollController controller, bool canUseAi) {
    final word = _word!;
    final lang = ref.watch(currentLanguageProvider);
    final definition = TranslationHelper.getDefinition(word, lang);

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      children: [
        _buildHandle(),
        const SizedBox(height: 20),
        _buildHeader(word),
        const SizedBox(height: 4),
        Text(
          word.pinyin,
          style: const TextStyle(color: AppColors.primary, fontSize: 18),
        ),
        const SizedBox(height: 16),
        const Divider(color: Color(0x229E9E9E)),
        const SizedBox(height: 12),
        Text(
          definition,
          style: const TextStyle(
            color: AppColors.onSurface,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        _buildYouglishButton(word),
        const SizedBox(height: 24),
        _buildAiSection(canUseAi),
      ],
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.onSurfaceMuted,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(DictionaryModel word) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          word.simplified,
          style: const TextStyle(
            color: AppColors.onSurface,
            fontSize: 44,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (word.traditional != word.simplified) ...[
          const SizedBox(width: 12),
          Text(
            word.traditional,
            style: const TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 28,
            ),
          ),
        ],
        const Spacer(),
        _HskChip(level: word.hskLevel),
      ],
    );
  }

  Widget _buildYouglishButton(DictionaryModel word) {
    final encoded = Uri.encodeComponent(word.simplified);
    final uri = Uri.parse('https://youglish.com/pronounce/$encoded/chinese');
    return OutlinedButton.icon(
      onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
      icon: const Icon(Icons.hearing_outlined, size: 18),
      label: const Text('Hear it used by natives (YouGlish)'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.onSurface,
        side: const BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(vertical: 12),
        minimumSize: const Size(double.infinity, 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildAiSection(bool canUseAi) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x339E9E9E)),
      ),
      child: switch (_aiStatus) {
        _AiStatus.idle => _buildAiIdle(canUseAi),
        _AiStatus.loading => _buildAiLoading(),
        _AiStatus.cached => _buildAiResult(fromCache: true),
        _AiStatus.fresh => _buildAiResult(fromCache: false),
        _AiStatus.error => _buildAiError(),
      },
    );
  }

  Widget _buildAiIdle(bool canUseAi) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
              SizedBox(width: 8),
              Text(
                'AI Context Explanation',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (canUseAi) ...[
            Text(
              'Explain "${_word!.simplified}" in the context of this sentence.',
              style: const TextStyle(
                color: AppColors.onSurfaceMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _requestExplanation,
                icon: const Icon(Icons.bolt, size: 18),
                label: const Text('Explain  (1 credit)'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ] else ...[
            const Text(
              'You have 0 AI credits.',
              style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            const RewardAdWidget(),
          ],
        ],
      ),
    );
  }

  Widget _buildAiLoading() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Generating explanation…',
            style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildAiResult({required bool fromCache}) {
    final result = _aiResult!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              const Text(
                'AI Explanation',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: fromCache
                      ? const Color(0x224CAF50)
                      : const Color(0x22E63946),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  fromCache ? 'cached' : 'fresh',
                  style: TextStyle(
                    color:
                        fromCache ? AppColors.hsk1 : AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.explanation,
            style: const TextStyle(
              color: AppColors.onSurface,
              fontSize: 14,
              height: 1.55,
            ),
          ),
          if (result.grammarNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x11E63946),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📝 ', style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: Text(
                      result.grammarNote,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiError() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.wrongAnswer, size: 16),
              SizedBox(width: 8),
              Text(
                'Explanation failed',
                style: TextStyle(
                  color: AppColors.wrongAnswer,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _aiError ?? 'Unknown error.',
            style: const TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              _aiStatus = _AiStatus.idle;
              _aiError = null;
            }),
            child: const Text(
              'Try again',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _HskChip extends StatelessWidget {
  final int level;
  const _HskChip({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.forHskLevel(level),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        level >= 7 ? 'Diğer' : 'HSK $level',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}
