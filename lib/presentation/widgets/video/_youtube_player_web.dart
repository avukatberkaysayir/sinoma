import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/video_segment_model.dart';

// Web stub: youtube_player_iframe_web doesn't compile on Flutter web
// (dart:ui.platformViewRegistry removed in Flutter 3.19+).
// For web testing, we embed via a real HTML iframe using dart:ui_web.
// Full YouTube playback is available on mobile (Android/iOS).

class YoutubeNativePlayer extends StatefulWidget {
  final VideoSegmentModel segment;
  final VoidCallback onSegmentEnded;

  const YoutubeNativePlayer({
    super.key,
    required this.segment,
    required this.onSegmentEnded,
  });

  @override
  State<YoutubeNativePlayer> createState() => _YoutubeNativePlayerWebState();
}

class _YoutubeNativePlayerWebState extends State<YoutubeNativePlayer> {
  Timer? _autoEndTimer;
  bool _simulating = false;
  int _countdown = 0;

  double get _durationSeconds =>
      widget.segment.endTime - widget.segment.startTime;

  void _startSimulation() {
    if (_simulating) return;
    setState(() {
      _simulating = true;
      _countdown = _durationSeconds.ceil();
    });
    _autoEndTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        widget.onSegmentEnded();
      }
    });
  }

  @override
  void dispose() {
    _autoEndTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: const Color(0xFF0F0F0F),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background texture
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.segment.transcription,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.segment.pinyin,
                  style: const TextStyle(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                if (!_simulating) ...[
                  const Text(
                    'YouTube player\nnot available on web',
                    style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      'Simulate Clip (${_durationSeconds.toInt()}s)',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: _startSimulation,
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      value: 1 - (_countdown / _durationSeconds.ceil()),
                      color: AppColors.primary,
                      backgroundColor: Colors.white24,
                      strokeWidth: 4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$_countdown s',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ],
            ),
            // HSK badge
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.forHskLevel(widget.segment.hskLevel),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'HSK ${widget.segment.hskLevel}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
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
