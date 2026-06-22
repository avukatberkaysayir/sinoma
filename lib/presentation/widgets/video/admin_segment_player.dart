// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

// Admin preview player. Uses the NATIVE YouTube embed `start`/`end` URL params
// (like the home player) instead of the youtube_player_iframe package, whose
// JS command channel (loadVideoById/seekTo) doesn't take effect on Flutter web —
// that's why the package preview ignored the cut and played from 0 to the end.
class AdminSegmentPlayer extends StatefulWidget {
  final String youtubeId;
  final double startTime;
  final double endTime;
  final double width;
  final double height;

  const AdminSegmentPlayer({
    super.key,
    required this.youtubeId,
    required this.startTime,
    required this.endTime,
    this.width = 400,
    this.height = 225,
  });

  @override
  State<AdminSegmentPlayer> createState() => AdminSegmentPlayerState();
}

class AdminSegmentPlayerState extends State<AdminSegmentPlayer> {
  late final String _viewType;
  html.IFrameElement? _iframe;

  String _src() {
    final s = widget.startTime.toInt();
    final e =
        widget.endTime > widget.startTime ? widget.endTime.ceil() : s + 1;
    final origin = Uri.encodeComponent(html.window.location.origin);
    return 'https://www.youtube.com/embed/${widget.youtubeId}'
        '?start=$s&end=$e&autoplay=1&controls=1&rel=0&playsinline=1'
        '&enablejsapi=1&origin=$origin';
  }

  @override
  void initState() {
    super.initState();
    _viewType = 'admin-yt-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final f = html.IFrameElement()
        ..src = _src()
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'autoplay; fullscreen; encrypted-media'
        ..setAttribute('allowfullscreen', '');
      _iframe = f;
      return f;
    });
  }

  // Re-cue the segment from its start (the native start/end re-apply on reload).
  void replay() => _iframe?.src = _src();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
