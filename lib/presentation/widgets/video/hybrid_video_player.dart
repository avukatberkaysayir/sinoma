import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/video_segment_model.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/video_provider.dart';
import '../ads/ad_banner_widget.dart';
import '../quiz/quiz_overlay.dart';
import 'self_hosted_player.dart';
import 'youtube_section_player.dart';

/// Routes to the correct player based on VideoSegmentModel.sourceType.
/// Handles quiz overlay, blur effect, and AdMob banner below player.
class HybridVideoPlayer extends ConsumerWidget {
  final VideoSegmentModel segment;
  final VoidCallback onVideoCompleted;

  const HybridVideoPlayer({
    super.key,
    required this.segment,
    required this.onVideoCompleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(videoPlaybackProvider);
    final isQuizVisible = playbackState.status == VideoPlaybackStatus.quizActive;
    final subscriptionState = ref.watch(subscriptionProvider);

    return Column(
      children: [
        Stack(
          children: [
            _buildPlayer(ref),
            if (isQuizVisible)
              const Positioned.fill(
                child: ColoredBox(color: Color(0x66000000)),
              ),
            if (isQuizVisible)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: QuizOverlay(
                  quiz: segment.quiz,
                  onAnswered: onVideoCompleted,
                ),
              ),
          ],
        ),
        if (subscriptionState.showAds) const AdBannerWidget(),
      ],
    );
  }

  Widget _buildPlayer(WidgetRef ref) {
    void onEnded() {
      ref.read(videoPlaybackProvider.notifier).activateQuiz();
    }

    return switch (segment.sourceType) {
      VideoSourceType.youtube => YoutubeNativePlayer(
          segment: segment,
          onSegmentEnded: onEnded,
        ),
      VideoSourceType.selfHosted => SelfHostedPlayer(
          segment: segment,
          onSegmentEnded: onEnded,
        ),
    };
  }
}
