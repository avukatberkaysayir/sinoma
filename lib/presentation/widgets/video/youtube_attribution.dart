// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/locale_provider.dart';

// Required by the YouTube API Services Terms: the viewer must be able to tell
// that YouTube is the source. A visible link that opens the original video on
// YouTube (at the clip's start) satisfies the attribution requirement — and it
// sits OUTSIDE the player rectangle, so it never overlays the embed.
class YouTubeAttribution extends StatelessWidget {
  final String youtubeId;
  final double startTime;
  final EdgeInsetsGeometry padding;

  const YouTubeAttribution({
    super.key,
    required this.youtubeId,
    this.startTime = 0,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  });

  void _open() {
    if (youtubeId.isEmpty) return;
    final t = startTime.toInt();
    html.window.open(
      'https://www.youtube.com/watch?v=$youtubeId${t > 0 ? '&t=${t}s' : ''}',
      '_blank',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_circle_fill,
                    color: Color(0xFFFF0000), size: 18),
                const SizedBox(width: 6),
                Text(
                  AppL10n.of(context).watchOnYouTube,
                  style: TextStyle(
                    color: AppColors.text70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
