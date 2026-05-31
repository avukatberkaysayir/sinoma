// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';

// ── Controller ───────────────────────────────────────────────────────────────

class DirectYouTubeController extends ChangeNotifier {
  _DirectYouTubePlayerState? _state;

  void _attach(_DirectYouTubePlayerState s) => _state = s;
  void _detach() => _state = null;

  bool get soundOn => _state?._soundOn ?? false;
  void toggleSound() => _state?._toggleSound();

  void pauseVideo() => _state?._cmd('pauseVideo', []);
  void playVideo() => _state?._cmd('playVideo', []);
  void seekTo(double seconds) => _state?._cmd('seekTo', [seconds, true]);
  void setPlaybackRate(double rate) => _state?._cmd('setPlaybackRate', [rate]);

  void _notify() => notifyListeners();
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
  final ValueChanged<bool>? onSoundChanged;

  const DirectYouTubePlayer({
    super.key,
    required this.videoId,
    required this.startTime,
    required this.endTime,
    required this.hskLevel,
    required this.replayCount,
    required this.controller,
    required this.onSegmentEnded,
    this.onSoundChanged,
  });

  @override
  State<DirectYouTubePlayer> createState() => _DirectYouTubePlayerState();
}

class _DirectYouTubePlayerState extends State<DirectYouTubePlayer> {
  // Set true once the user has interacted with the page in this session. After
  // that, Chrome allows autoplay WITH sound, so every later clip starts unmuted.
  static bool _pageInteracted = false;
  // Persists the user's explicit choice across clips.
  static bool _mutedByUser = false;

  static const _gestureEvents = [
    'pointerdown', 'mousedown', 'keydown', 'touchstart', 'mousemove', 'wheel',
  ];
  static const _hardEvents = {
    'pointerdown', 'mousedown', 'keydown', 'touchstart',
  };

  final GlobalKey _containerKey = GlobalKey();

  html.IFrameElement? _iframe;
  html.EventListener? _msgListener;
  html.EventListener? _gestureListener;

  Timer? _listenTimer; // re-sends the listening handshake until events arrive
  int _listenTries = 0;
  bool _eventsFlowing = false;

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
      // Filter by origin, not by source identity: comparing e.source to
      // _iframe.contentWindow is unreliable in dart:html (different Dart
      // wrappers for the same JS window) and silently dropped every message.
      final origin = e.origin;
      if (origin.isNotEmpty && !origin.contains('youtube')) return;
      Map<String, dynamic>? map;
      final d = e.data;
      try {
        if (d is String) {
          map = jsonDecode(d) as Map<String, dynamic>;
        } else if (d is Map) {
          map = Map<String, dynamic>.from(d);
        }
      } catch (_) {}
      if (map == null || map['event'] == null) return;
      _onYTMessage(map);
    };
    html.window.addEventListener('message', _msgListener!);

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
    // Chrome permits without a gesture. Any later clip → unmuted autoplay.
    final muted = !_pageInteracted || _mutedByUser;
    _soundOn = !muted;

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
          '&start=${widget.startTime.toInt()}'
          '&origin=$origin'
      ..allow = 'autoplay; fullscreen; encrypted-media'
      ..setAttribute('allowfullscreen', '')
      ..style.position = 'fixed'
      ..style.border = 'none'
      ..style.zIndex = '5'
      // Pass clicks/mouse-moves through to the page so interaction anywhere
      // (incl. over the video) is detected; our controls live below the video.
      ..style.pointerEvents = 'none';

    // Subscribe to the player's event stream once the frame document loads.
    frame.onLoad.listen((_) => _startListening());

    _iframe = frame;
    _applyGeometry();
    html.document.body!.append(frame);
    widget.controller._notify();
  }

  // The YouTube iframe only streams infoDelivery (currentTime / state / muted)
  // to windows that registered with a 'listening' message that includes
  // channel:'widget'. Re-send it until the first event confirms it took.
  void _startListening() {
    _sendListening();
    _listenTimer?.cancel();
    _listenTries = 0;
    _listenTimer = Timer.periodic(const Duration(milliseconds: 700), (t) {
      if (_eventsFlowing || _listenTries++ > 10) {
        t.cancel();
        return;
      }
      _sendListening();
    });
  }

  void _sendListening() {
    _iframe?.contentWindow?.postMessage(
      jsonEncode({'event': 'listening', 'id': 1, 'channel': 'widget'}),
      '*',
    );
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

  // ── Sound ────────────────────────────────────────────────────────────────

  void _tryUnmute() {
    if (_soundOn || _mutedByUser) return;
    final now = DateTime.now();
    if (now.difference(_lastUnmuteTry).inMilliseconds < 400) return;
    _lastUnmuteTry = now;
    _cmd('unMute', []);
    _cmd('setVolume', [100]);
  }

  void _toggleSound() {
    if (_soundOn) {
      _mutedByUser = true;
      _cmd('mute', []);
      _applySound(false);
    } else {
      _mutedByUser = false;
      _pageInteracted = true;
      _lastUnmuteTry = DateTime.fromMillisecondsSinceEpoch(0);
      _cmd('unMute', []);
      _cmd('setVolume', [100]);
      _applySound(true);
    }
  }

  void _applySound(bool on) {
    if (_soundOn == on) return;
    _soundOn = on;
    widget.controller._notify();
    widget.onSoundChanged?.call(on);
  }

  // ── YouTube postMessage protocol ───────────────────────────────────────────

  void _onYTMessage(Map<String, dynamic> data) {
    final event = data['event'] as String?;

    if (event == 'onReady') {
      _startListening();
      _cmd('playVideo', []);
    } else if (event == 'infoDelivery') {
      _eventsFlowing = true;
      _listenTimer?.cancel();

      final info = data['info'];
      if (info is Map) {
        final state = (info['playerState'] as num?)?.toInt();
        if (state == 1) _markPlaying();

        final muted = info['muted'];
        final volume = (info['volume'] as num?)?.toInt();
        if (muted is bool) {
          _applySound(!muted && (volume == null || volume > 0));
        }

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
    _listenTimer?.cancel();
    if (_msgListener != null) {
      html.window.removeEventListener('message', _msgListener!);
    }
    if (_gestureListener != null) {
      for (final type in _gestureEvents) {
        html.document.removeEventListener(type, _gestureListener!, true);
      }
    }
    _iframe?.remove();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updatePosition());

    // The video (iframe) is a body-appended DOM element layered above this;
    // here we only reserve the 16:9 space for geometry. The sound toggle lives
    // in the controls bar below the video (see InlinePlayerSection).
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        key: _containerKey,
        color: Colors.black,
      ),
    );
  }
}
