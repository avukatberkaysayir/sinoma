import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/video_segment_model.dart';

class SelfHostedPlayer extends StatefulWidget {
  final VideoSegmentModel segment;
  final VoidCallback onSegmentEnded;

  const SelfHostedPlayer({
    super.key,
    required this.segment,
    required this.onSegmentEnded,
  });

  @override
  State<SelfHostedPlayer> createState() => _SelfHostedPlayerState();
}

class _SelfHostedPlayerState extends State<SelfHostedPlayer> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _hasTriggeredEnd = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.segment.videoUrl!),
    );
    await _videoController.initialize();
    await _videoController.seekTo(Duration(seconds: widget.segment.startTime.toInt()));

    _chewieController = ChewieController(
      videoPlayerController: _videoController,
      autoPlay: true,
      looping: false,
      showControls: true,
      allowFullScreen: false,
    );

    _videoController.addListener(_onPositionChange);
    if (mounted) setState(() {});
  }

  void _onPositionChange() {
    if (_hasTriggeredEnd) return;
    final position = _videoController.value.position.inSeconds.toDouble();

    if (position >= widget.segment.endTime) {
      _hasTriggeredEnd = true;
      _videoController.pause();
      widget.onSegmentEnded();
    }
  }

  @override
  void dispose() {
    _videoController.removeListener(_onPositionChange);
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_chewieController == null) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          Chewie(controller: _chewieController!),
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
