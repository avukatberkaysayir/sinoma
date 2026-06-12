import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../../data/models/video_segment_model.dart';
import '../../providers/ai_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/video_provider.dart';
import '../../widgets/common/score_hud.dart';
import '../../widgets/common/subtitle_bar.dart';
import '../../widgets/common/word_detail_sheet.dart';
import '../../widgets/video/hybrid_video_player.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String videoId;

  const VideoPlayerScreen({super.key, required this.videoId});

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  VideoSegmentModel? _segment;
  bool _isLoading = true;
  String? _error;
  String? _activeWordId;

  @override
  void initState() {
    super.initState();
    _loadSegment();
  }

  Future<void> _loadSegment() async {
    try {
      final segment =
          await ref.read(videoRepositoryProvider).loadSegment(widget.videoId);
      if (!mounted) return;

      if (segment == null) {
        setState(() {
          _error = 'Video segment not found.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _segment = segment;
        _isLoading = false;
      });

      ref.read(videoPlaybackProvider.notifier).loadSegment(segment);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onVideoCompleted() {
    final isPremium = ref.read(subscriptionProvider).isPremium;

    if (!isPremium) {
      ref.read(adServiceProvider).recordVideoCompleted();
    }

    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      if (!ref.read(subscriptionProvider).isPremium) {
        await ref.read(adServiceProvider).showInterstitialIfEligible();
      }
      if (mounted) context.pop();
    });
  }

  void _showWordDetail(String word) {
    final segment = _segment!;
    if (ResponsiveLayout.isWide(context)) {
      // On wide screens show inline side panel instead of bottom sheet.
      setState(() => _activeWordId = word);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WordDetailSheet(
        wordId: word,
        transcription: segment.transcription,
        hskLevel: segment.hskLevel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _segment == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(),
        body: Center(
          child: Text(
            _error ?? 'Unknown error',
            style: TextStyle(color: AppColors.onSurface),
          ),
        ),
      );
    }

    final segment = _segment!;
    final playbackState = ref.watch(videoPlaybackProvider);
    final isWide = ResponsiveLayout.isWide(context);

    final playerColumn = SafeArea(
      child: Column(
        children: [
          ScoreHud(state: playbackState),
          HybridVideoPlayer(
            segment: segment,
            onVideoCompleted: _onVideoCompleted,
          ),
          SubtitleBar(
            transcription: segment.transcription,
            pinyin: segment.pinyin,
            targetWords: segment.targetWords,
            onWordTapped: _showWordDetail,
          ),
          const Spacer(),
          if (playbackState.status == VideoPlaybackStatus.completed)
            _CompletionBanner(wasCorrect: playbackState.wasCorrect),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: isWide
          ? Row(
              children: [
                // Player constrained to a max width, centred in remaining space.
                Expanded(
                  flex: 3,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: playerColumn,
                  ),
                ),
                // Side panel: word detail or placeholder.
                Expanded(
                  flex: 2,
                  child: Container(
                    color: AppColors.surfaceVariant,
                    child: _activeWordId != null
                        ? _SideWordDetail(
                            wordId: _activeWordId!,
                            transcription: segment.transcription,
                            hskLevel: segment.hskLevel,
                            onClose: () =>
                                setState(() => _activeWordId = null),
                          )
                        : Center(
                            child: Text(
                              'Tap a word to see its definition',
                              style: TextStyle(
                                color: AppColors.onSurfaceMuted,
                                fontSize: 14,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            )
          : playerColumn,
    );
  }
}

// ---------------------------------------------------------------------------
// Wide-screen side panel — wraps WordDetailSheet content inline
// ---------------------------------------------------------------------------

class _SideWordDetail extends StatelessWidget {
  final String wordId;
  final String transcription;
  final int hskLevel;
  final VoidCallback onClose;

  const _SideWordDetail({
    required this.wordId,
    required this.transcription,
    required this.hskLevel,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Word Detail',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: AppColors.onSurfaceMuted),
                onPressed: onClose,
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.surface),
        Expanded(
          child: SingleChildScrollView(
            child: WordDetailSheet(
              wordId: wordId,
              transcription: transcription,
              hskLevel: hskLevel,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _CompletionBanner extends StatelessWidget {
  final bool wasCorrect;

  const _CompletionBanner({required this.wasCorrect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: wasCorrect ? AppColors.correctAnswer : AppColors.wrongAnswer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            wasCorrect ? Icons.check_circle : Icons.cancel,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            wasCorrect ? '正确！ Great job!' : '再试试！ Try again!',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
