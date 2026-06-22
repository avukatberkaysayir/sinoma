import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/video_segment_model.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/video_provider.dart';
import '../ads/ad_banner_widget.dart';
import '../quiz/quiz_overlay.dart';
import 'direct_youtube_player.dart';
import 'self_hosted_player.dart';

class HybridVideoPlayer extends ConsumerStatefulWidget {
  final VideoSegmentModel segment;
  final VoidCallback onVideoCompleted;

  const HybridVideoPlayer({
    super.key,
    required this.segment,
    required this.onVideoCompleted,
  });

  @override
  ConsumerState<HybridVideoPlayer> createState() => _HybridVideoPlayerState();
}

class _HybridVideoPlayerState extends ConsumerState<HybridVideoPlayer> {
  final DirectYouTubeController _ytCtrl = DirectYouTubeController();

  @override
  Widget build(BuildContext context) {
    final playbackState = ref.watch(videoPlaybackProvider);
    final isQuizVisible = playbackState.status == VideoPlaybackStatus.quizActive;
    final subscriptionState = ref.watch(subscriptionProvider);

    return Column(
      children: [
        Stack(
          children: [
            _buildPlayer(),
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
                  quiz: widget.segment.quiz,
                  onAnswered: widget.onVideoCompleted,
                ),
              ),
          ],
        ),
        if (subscriptionState.showAds) const AdBannerWidget(),
      ],
    );
  }

  Widget _buildPlayer() {
    void onEnded() {
      ref.read(videoPlaybackProvider.notifier).activateQuiz();
    }

    return switch (widget.segment.sourceType) {
      VideoSourceType.youtube => DirectYouTubePlayer(
          key: ValueKey('${widget.segment.videoId}-${widget.segment.startTime}'),
          videoId: widget.segment.youtubeId ?? '',
          startTime: widget.segment.startTime,
          endTime: widget.segment.endTime,
          replayCount: 0,
          controller: _ytCtrl,
          onSegmentEnded: onEnded,
          onEmbedError: onEnded,
        ),
      VideoSourceType.selfHosted => SelfHostedPlayer(
          segment: widget.segment,
          onSegmentEnded: onEnded,
        ),
    };
  }
}
