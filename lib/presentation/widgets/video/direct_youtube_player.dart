// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';

// ── Controller ───────────────────────────────────────────────────────────────

class DirectYouTubeController {
  _DirectYouTubePlayerState? _state;

  void _attach(_DirectYouTubePlayerState s) => _state = s;
  void _detach() => _state = null;

  void pauseVideo() => _state?._cmd('pauseVideo', []);
  void playVideo() => _state?._cmd('playVideo', []);
  void seekTo(double seconds) => _state?._cmd('seekTo', [seconds, true]);
  void setPlaybackRate(double rate) => _state?._cmd('setPlaybackRate', [rate]);
}

// ── Widget ───────────────────────────────────────────────────────────────────

class DirectYouTubePlayer extends StatefulWidget {
  final String videoId;
  final double startTime;
  final double endTime;
  final int hskLevel;
  final int replayCount;
  final DirectYouTubeController controller;
  final VoidCallback onSegmentEnded;

  const DirectYouTubePlayer({
    super.key,
    required this.videoId,
    required this.startTime,
    required this.endTime,
    required this.hskLevel,
    required this.replayCount,
    required this.controller,
    required this.onSegmentEnded,
  });

  @override
  State<DirectYouTubePlayer> createState() => _DirectYouTubePlayerState();
}

class _DirectYouTubePlayerState extends State<DirectYouTubePlayer> {
  final GlobalKey _containerKey = GlobalKey();

  html.IFrameElement? _iframe;
  html.EventListener? _msgListener;
  html.EventListener? _gestureListener;

  bool _soundOn = false;
  bool _hasPlayed = false;
  bool _ended = false;
  double _lastTime = 0;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    _lastTime = widget.startTime;

    // One message listener for the lifetime of the widget; it validates the
    // source against the current iframe, so it keeps working across a reload.
    _msgListener = (html.Event e) {
      if (e is! html.MessageEvent) return;
      if (e.source != _iframe?.contentWindow) return;
      try {
        final raw = e.data?.toString();
        if (raw == null) return;
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _onYTMessage(data);
      } catch (_) {}
    };
    html.window.addEventListener('message', _msgListener!);

    // First real interaction anywhere on the page → try the cheap unmute path
    // (works when the document already has a sticky user activation, e.g. the
    // user navigated here by clicking). If it doesn't take, the visible
    // speaker button reloads the player with sound — see _turnSoundOn().
    _gestureListener = (_) {
      if (!_soundOn) _cmd('unMute', []);
    };
    html.document.addEventListener('pointerdown', _gestureListener!, true);
    html.document.addEventListener('keydown', _gestureListener!, true);

    // Create the player + muted-autoplay after first layout (container sized).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _buildIframe(muted: true, startAt: widget.startTime);
    });
  }

  // ── iframe ─────────────────────────────────────────────────────────────────

  void _buildIframe({required bool muted, required double startAt}) {
    final origin = Uri.encodeComponent(html.window.location.origin);
    final muteParam = muted ? '&mute=1' : '';

    final frame = html.IFrameElement()
      ..src = 'https://www.youtube.com/embed/${widget.videoId}'
          '?autoplay=1'
          '$muteParam'
          '&controls=0'
          '&rel=0'
          '&playsinline=1'
          '&enablejsapi=1'
          '&start=${startAt.toInt()}'
          '&origin=$origin'
      ..allow = 'autoplay; fullscreen; encrypted-media'
      ..setAttribute('allowfullscreen', '')
      ..style.position = 'fixed'
      ..style.border = 'none'
      ..style.zIndex = '5';

    _iframe = frame;
    _applyGeometry();
    html.document.body!.append(frame);
  }

  // Reload the player WITHOUT mute, resuming at the current time. Called from a
  // real user gesture (button tap), so the fresh autoplay is granted with
  // sound — the reliable way to unmute a cross-origin YouTube embed.
  void _turnSoundOn() {
    if (_soundOn) return;
    final resumeAt = (_lastTime > widget.startTime - 1)
        ? _lastTime
        : widget.startTime;
    _iframe?.remove();
    _buildIframe(muted: false, startAt: resumeAt);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updatePosition());
  }

  void _applyGeometry() {
    final box = _containerKey.currentContext?.findRenderObject() as RenderBox?;
    final style = _iframe?.style;
    if (style == null) return;
    if (box == null || !box.hasSize) {
      style
        ..left = '0'
        ..top = '0'
        ..width = '100vw'
        ..height = '56.25vw';
      return;
    }
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    style
      ..left = '${pos.dx}px'
      ..top = '${pos.dy}px'
      ..width = '${size.width}px'
      ..height = '${size.height}px';
  }

  void _updatePosition() {
    if (!mounted) return;
    _applyGeometry();
  }

  // ── YouTube postMessage protocol ───────────────────────────────────────────

  void _onYTMessage(Map<String, dynamic> data) {
    final event = data['event'] as String?;

    if (event == 'onReady') {
      _iframe?.contentWindow
          ?.postMessage(jsonEncode({'event': 'listening', 'id': 1}), '*');
      _cmd('playVideo', []);
    } else if (event == 'infoDelivery') {
      final info = data['info'];
      if (info is Map) {
        final state = (info['playerState'] as num?)?.toInt();
        if (state == 1) _markPlaying();

        final muted = info['muted'];
        final volume = (info['volume'] as num?)?.toInt();
        final soundNow = (muted == false) && (volume == null || volume > 0);
        if (soundNow != _soundOn && mounted) {
          setState(() => _soundOn = soundNow);
        }

        final t = (info['currentTime'] as num?)?.toDouble();
        if (t != null) {
          _lastTime = t;
          if (_hasPlayed) _handleTime(t);
        }
      }
    } else if (event == 'onStateChange') {
      final state = (data['info'] as num?)?.toInt();
      if (state == 1) _markPlaying();
    }
  }

  void _markPlaying() {
    if (_hasPlayed) return;
    _hasPlayed = true;
  }

  void _handleTime(double t) {
    if (t <= 0) return;

    if (!_ended && t >= widget.endTime) {
      _ended = true;
      _cmd('pauseVideo', []);
      widget.onSegmentEnded();
      return;
    }

    if (t < widget.startTime - 1) {
      _cmd('seekTo', [widget.startTime, true]);
    }
  }

  void _cmd(String func, List<dynamic> args) {
    _iframe?.contentWindow?.postMessage(
      jsonEncode({'event': 'command', 'func': func, 'args': args}),
      '*',
    );
  }

  // ── Replay ─────────────────────────────────────────────────────────────────

  @override
  void didUpdateWidget(DirectYouTubePlayer old) {
    super.didUpdateWidget(old);
    if (widget.replayCount != old.replayCount) {
      _ended = false;
      _hasPlayed = false;
      _cmd('seekTo', [widget.startTime, true]);
      _cmd('playVideo', []);
    }
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    widget.controller._detach();
    if (_msgListener != null) {
      html.window.removeEventListener('message', _msgListener!);
    }
    if (_gestureListener != null) {
      html.document.removeEventListener('pointerdown', _gestureListener!, true);
      html.document.removeEventListener('keydown', _gestureListener!, true);
    }
    _iframe?.remove();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updatePosition());

    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            key: _containerKey,
            color: Colors.black,
          ),
        ),
        if (!_soundOn)
          Positioned(
            bottom: 10,
            right: 10,
            child: GestureDetector(
              onTap: _turnSoundOn,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.volume_off_rounded,
                        color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Ses için dokun',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
