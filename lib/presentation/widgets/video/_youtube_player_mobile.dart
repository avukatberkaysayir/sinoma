import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/video_segment_model.dart';

class YoutubeNativePlayer extends StatefulWidget {
  final VideoSegmentModel segment;
  final VoidCallback onSegmentEnded;

  const YoutubeNativePlayer({
    super.key,
    required this.segment,
    required this.onSegmentEnded,
  });

  @override
  State<YoutubeNativePlayer> createState() => _YoutubeNativePlayerState();
}

class _YoutubeNativePlayerState extends State<YoutubeNativePlayer> {
  late YoutubePlayerController _controller;
  Timer? _positionTimer;
  bool _hasTriggeredEnd = false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        mute: false,
        loop: false,
        playsInline: true,
      ),
    );
    _controller.loadVideoById(
      videoId: widget.segment.youtubeId!,
      startSeconds: widget.segment.startTime,
      endSeconds: widget.segment.endTime,
    );
    _startPositionMonitor();
  }

  void _startPositionMonitor() {
    _positionTimer =
        Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (_hasTriggeredEnd) return;
      final seconds = await _controller.currentTime;
      if (seconds >= widget.segment.endTime) {
        _hasTriggeredEnd = true;
        await _controller.pauseVideo();
        widget.onSegmentEnded();
        return;
      }
      if (seconds < widget.segment.startTime - 1) {
        await _controller.seekTo(
          seconds: widget.segment.startTime,
          allowSeekAhead: true,
        );
      }
    });
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          YoutubePlayer(controller: _controller),
          Positioned(
            top: 8,
            right: 8,
            child: _HskBadge(level: widget.segment.hskLevel),
          ),
        ],
      ),
    );
  }
}

class _HskBadge extends StatelessWidget {
  final int level;
  const _HskBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.forHskLevel(level),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'HSK $level',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
