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
  // Set true once the user has interacted with the page in this session. After
  // that, Chrome allows autoplay WITH sound, so every later clip starts unmuted.
  static bool _pageInteracted = false;
  // Persists the user's explicit choice across clips: if they tap to mute, auto-
  // unmute (and the next clips) stay muted until they tap to turn sound back on.
  static bool _mutedByUser = false;

  // Any of these on the page tries to turn sound on. The "hard" ones also count
  // as a real user activation (so the next clips start unmuted); the soft ones
  // (mousemove/wheel) only unmute when an activation already exists — Chrome
  // never grants a NEW activation from mouse movement or scrolling.
  static const _gestureEvents = [
    'pointerdown', 'mousedown', 'keydown', 'touchstart', 'mousemove', 'wheel',
  ];
  static const _hardEvents = {
    'pointerdown', 'mousedown', 'keydown', 'touchstart',
  };

  final GlobalKey _containerKey = GlobalKey();

  html.IFrameElement? _iframe;
  html.DivElement? _soundBtn; // DOM, sits ABOVE the iframe so it's always usable
  html.EventListener? _msgListener;
  html.EventListener? _gestureListener;

  bool _soundOn = false;
  bool _hasPlayed = false;
  bool _ended = false;
  DateTime _lastUnmuteTry = DateTime.fromMillisecondsSinceEpoch(0);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);

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

    // Turn sound on at the lightest interaction (incl. mouse movement). Capture
    // phase so it runs before Flutter consumes the event.
    _gestureListener = (e) {
      if (_hardEvents.contains(e.type)) _pageInteracted = true;
      _tryUnmute();
    };
    for (final type in _gestureEvents) {
      html.document.addEventListener(type, _gestureListener!, true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _buildIframe();
    });
  }

  // ── iframe ─────────────────────────────────────────────────────────────────

  void _buildIframe() {
    if (_iframe != null) return;

    // Cold first load (no interaction yet) → muted autoplay, the only kind
    // Chrome permits without a gesture. Any later clip (the user got here by
    // clicking) → unmuted autoplay. A manual mute choice is always respected.
    final muted = !_pageInteracted || _mutedByUser;
    _soundOn = !muted;

    final origin = Uri.encodeComponent(html.window.location.origin);
    final muteParam = muted ? '&mute=1' : '';

    _iframe = html.IFrameElement()
      ..src = 'https://www.youtube.com/embed/${widget.videoId}'
          '?autoplay=1'
          '$muteParam'
          '&controls=0'
          '&rel=0'
          '&playsinline=1'
          '&enablejsapi=1'
          '&start=${widget.startTime.toInt()}'
          '&origin=$origin'
      ..allow = 'autoplay; fullscreen; encrypted-media'
      ..setAttribute('allowfullscreen', '')
      ..style.position = 'fixed'
      ..style.border = 'none'
      ..style.zIndex = '5'
      // Let clicks/mouse-moves pass through to the page below so interaction
      // anywhere (incl. over the video) is detected. Controls are ours, so the
      // iframe itself never needs pointer input.
      ..style.pointerEvents = 'none';

    html.document.body!.append(_iframe!);
    _buildSoundButton();
    _applyGeometry();
  }

  // Sound toggle as a DOM element at a higher z-index than the iframe, so it is
  // always visible and clickable over the video (a Flutter widget would render
  // behind the body-appended iframe and be unusable once the video loads).
  void _buildSoundButton() {
    if (_soundBtn != null) return;
    final btn = html.DivElement()
      ..style.position = 'fixed'
      ..style.zIndex = '7'
      ..style.cursor = 'pointer'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.gap = '6px'
      ..style.padding = '7px 12px'
      ..style.borderRadius = '20px'
      ..style.background = 'rgba(0,0,0,0.72)'
      ..style.border = '1px solid rgba(255,255,255,0.24)'
      ..style.color = 'white'
      ..style.fontFamily = 'sans-serif'
      ..style.fontSize = '12px'
      ..style.userSelect = 'none'
      ..style.whiteSpace = 'nowrap';
    btn.onClick.listen((e) {
      e.stopPropagation();
      _toggleSound();
    });
    _soundBtn = btn;
    html.document.body!.append(btn);
    _refreshSoundButton();
  }

  void _refreshSoundButton() {
    _soundBtn?.text = _soundOn ? '🔊' : '🔇 Ses için dokun';
  }

  // Attempt to unmute, throttled — mousemove fires constantly, so cap retries.
  // Skipped if the user has explicitly muted (their choice wins).
  void _tryUnmute() {
    if (_soundOn || _mutedByUser) return;
    final now = DateTime.now();
    if (now.difference(_lastUnmuteTry).inMilliseconds < 400) return;
    _lastUnmuteTry = now;
    _cmd('unMute', []);
    _cmd('setVolume', [100]);
  }

  void _requestSound() {
    _pageInteracted = true;
    _lastUnmuteTry = DateTime.fromMillisecondsSinceEpoch(0);
    _tryUnmute();
  }

  // The persistent speaker button toggles sound and remembers the choice.
  void _toggleSound() {
    if (_soundOn) {
      _mutedByUser = true;
      _cmd('mute', []);
      _applySound(false);
    } else {
      _mutedByUser = false;
      _requestSound();
      _applySound(true);
    }
  }

  void _applySound(bool on) {
    _soundOn = on;
    _refreshSoundButton();
  }

  void _applyGeometry() {
    final box = _containerKey.currentContext?.findRenderObject() as RenderBox?;
    final haveBox = box != null && box.hasSize;
    final iStyle = _iframe?.style;

    if (iStyle != null) {
      if (haveBox) {
        final pos = box.localToGlobal(Offset.zero);
        iStyle
          ..left = '${pos.dx}px'
          ..top = '${pos.dy}px'
          ..width = '${box.size.width}px'
          ..height = '${box.size.height}px';
      } else {
        iStyle
          ..left = '0'
          ..top = '0'
          ..width = '100vw'
          ..height = '56.25vw';
      }
    }

    // Anchor the sound button to the iframe's bottom-right corner using
    // right/bottom insets, so its own (variable) width doesn't matter.
    final bStyle = _soundBtn?.style;
    if (bStyle != null && haveBox) {
      final pos = box.localToGlobal(Offset.zero);
      final winW = html.window.innerWidth!.toDouble();
      final winH = html.window.innerHeight!.toDouble();
      bStyle
        ..left = ''
        ..top = ''
        ..right = '${winW - (pos.dx + box.size.width) + 10}px'
        ..bottom = '${winH - (pos.dy + box.size.height) + 10}px';
    }
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
        if (soundNow != _soundOn) _applySound(soundNow);

        final t = (info['currentTime'] as num?)?.toDouble();
        if (t != null && _hasPlayed) _handleTime(t);
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
      for (final type in _gestureEvents) {
        html.document.removeEventListener(type, _gestureListener!, true);
      }
    }
    _iframe?.remove();
    _soundBtn?.remove();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updatePosition());

    // The video (iframe) and the sound toggle are body-appended DOM elements
    // layered above this; here we only reserve the 16:9 space for geometry.
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        key: _containerKey,
        color: Colors.black,
      ),
    );
  }
}
