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
  void showScorePopup(int points) => _state?._showScorePopup(points);

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

  // Voscreen-style overlays drawn on top of the player.
  final int countdown; // seconds left to make a choice (e.g. 20..0)
  final bool showCountdown; // visible only during the choice window
  final bool showReplay; // segment ended, awaiting action
  final bool showNext; // appears after a subtitle choice is made
  final VoidCallback? onReplayTap;
  final VoidCallback? onNextTap;

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
    this.countdown = 0,
    this.showCountdown = false,
    this.showReplay = false,
    this.showNext = false,
    this.onReplayTap,
    this.onNextTap,
  });

  @override
  State<DirectYouTubePlayer> createState() => _DirectYouTubePlayerState();
}

class _DirectYouTubePlayerState extends State<DirectYouTubePlayer> {
  // Persisted in sessionStorage so hard-refresh within the same browser tab
  // doesn't reset the interaction state (and lose unmuted playback).
  static bool _pageInteracted = false;
  // Persisted in localStorage so the user's mute preference survives page loads.
  static bool _mutedByUser = false;

  static const _gestureEvents = [
    'pointerdown', 'mousedown', 'keydown', 'touchstart', 'mousemove', 'wheel',
  ];
  static const _hardEvents = {
    'pointerdown', 'mousedown', 'keydown', 'touchstart',
  };

  static void _loadStoredFlags() {
    try {
      if (html.window.sessionStorage['sinoma_interacted'] == '1') {
        _pageInteracted = true;
      }
    } catch (_) {}
    try {
      if (html.window.localStorage['sinoma_muted'] == '1') {
        _mutedByUser = true;
      }
    } catch (_) {}
  }

  static void _persistInteracted() {
    try { html.window.sessionStorage['sinoma_interacted'] = '1'; } catch (_) {}
  }

  static void _persistMuted(bool v) {
    try { html.window.localStorage['sinoma_muted'] = v ? '1' : '0'; } catch (_) {}
  }

  final GlobalKey _containerKey = GlobalKey();

  html.IFrameElement? _iframe;
  html.DivElement? _countdownEl; // top-right choice countdown
  html.DivElement? _replayEl; // center replay (segment end)
  html.DivElement? _nextEl; // right-center next arrow (always available)
  html.EventListener? _msgListener;
  html.EventListener? _gestureListener;

  Timer? _listenTimer;
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
    _loadStoredFlags();

    _msgListener = (html.Event e) {
      if (e is! html.MessageEvent) return;
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
      if (_hardEvents.contains(e.type) && !_pageInteracted) {
        _pageInteracted = true;
        _persistInteracted();
      }
      _tryUnmute();
    };
    for (final type in _gestureEvents) {
      html.document.addEventListener(type, _gestureListener!, true);
    }

    _injectPopupKeyframes();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _buildIframe();
    });
  }

  // Inject the score-pop animation once per document.
  void _injectPopupKeyframes() {
    if (html.document.getElementById('sinoma-score-pop') != null) return;
    final style = html.StyleElement()
      ..id = 'sinoma-score-pop'
      ..text = '@keyframes sinomaScorePop {'
          '0% { transform: translate(-50%, -50%) scale(0.4); opacity: 0; }'
          '25% { transform: translate(-50%, -50%) scale(1.2); opacity: 1; }'
          '55% { transform: translate(-50%, -50%) scale(1.0); opacity: 1; }'
          '100% { transform: translate(-50%, -50%) scale(0.9); opacity: 0; }'
          '}';
    html.document.head!.append(style);
  }

  // A transient circular burst over the player: green +N, red -N.
  void _showScorePopup(int points) {
    final box = _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final pos = box.localToGlobal(Offset.zero);
    final cx = pos.dx + box.size.width / 2;
    final cy = pos.dy + box.size.height / 2;
    final positive = points >= 0;

    final el = html.DivElement()
      ..text = positive ? '+$points' : '$points'
      ..style.position = 'fixed'
      ..style.zIndex = '9'
      ..style.pointerEvents = 'none'
      ..style.left = '${cx}px'
      ..style.top = '${cy}px'
      ..style.width = '96px'
      ..style.height = '96px'
      ..style.borderRadius = '50%'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.color = 'white'
      ..style.fontFamily = 'sans-serif'
      ..style.fontSize = '28px'
      ..style.fontWeight = '800'
      ..style.background = positive
          ? 'rgba(34, 197, 94, 0.95)'
          : 'rgba(239, 68, 68, 0.95)'
      ..style.boxShadow = '0 4px 18px rgba(0,0,0,0.4)'
      ..style.animation = 'sinomaScorePop 1.1s ease-out forwards';
    html.document.body!.append(el);
    Future.delayed(const Duration(milliseconds: 1150), el.remove);
  }

  // ── iframe + overlays ──────────────────────────────────────────────────────

  void _buildIframe() {
    if (_iframe != null) return;

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
      ..style.zIndex = '5';
    // No pointer-events:none — the user controls play/pause by clicking the
    // video (YouTube's native click handler). Our overlays sit above it.

    frame.onLoad.listen((_) => _startListening());

    _iframe = frame;
    html.document.body!.append(frame);
    _buildOverlays();
    _applyGeometry();
    widget.controller._notify();
  }

  void _buildOverlays() {
    // Countdown — top-right circular badge, non-interactive (clicks fall
    // through to the video). Shown only during the choice window.
    _countdownEl = html.DivElement()
      ..style.position = 'fixed'
      ..style.zIndex = '8'
      ..style.pointerEvents = 'none'
      ..style.display = 'none'
      ..style.width = '44px'
      ..style.height = '44px'
      ..style.borderRadius = '50%'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.background = 'rgba(0,0,0,0.55)'
      ..style.border = '2px solid #ef4444'
      ..style.color = 'white'
      ..style.fontFamily = 'sans-serif'
      ..style.fontSize = '16px'
      ..style.fontWeight = '700';
    html.document.body!.append(_countdownEl!);

    // Center replay (shown when the segment ends) — subtle dark circle with
    // just the replay glyph, no label.
    _replayEl = html.DivElement()
      ..text = '↻'
      ..style.position = 'fixed'
      ..style.zIndex = '8'
      ..style.display = 'none'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.width = '64px'
      ..style.height = '64px'
      ..style.borderRadius = '50%'
      ..style.cursor = 'pointer'
      ..style.background = 'rgba(0, 0, 0, 0.40)'
      ..style.border = '1px solid rgba(255,255,255,0.45)'
      ..style.color = 'white'
      ..style.fontFamily = 'sans-serif'
      ..style.fontSize = '32px'
      ..style.lineHeight = '1';
    _replayEl!.onClick.listen((e) {
      e.stopPropagation();
      widget.onReplayTap?.call();
    });
    html.document.body!.append(_replayEl!);

    // Right-center next arrow (shown after answering).
    _nextEl = html.DivElement()
      ..text = '›'
      ..style.position = 'fixed'
      ..style.zIndex = '8'
      ..style.display = 'none'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.width = '54px'
      ..style.height = '54px'
      ..style.borderRadius = '50%'
      ..style.cursor = 'pointer'
      ..style.background = 'rgba(255,255,255,0.92)'
      ..style.color = '#1a1a1a'
      ..style.fontSize = '34px'
      ..style.fontFamily = 'sans-serif'
      ..style.boxShadow = '0 2px 10px rgba(0,0,0,0.35)';
    _nextEl!.onClick.listen((e) {
      e.stopPropagation();
      widget.onNextTap?.call();
    });
    html.document.body!.append(_nextEl!);

    _refreshOverlays();
  }

  void _refreshOverlays() {
    final cd = _countdownEl?.style;
    if (cd != null) {
      cd.display = widget.showCountdown ? 'flex' : 'none';
    }
    _countdownEl?.text = '${widget.countdown}';
    _replayEl?.style.display = widget.showReplay ? 'flex' : 'none';
    _nextEl?.style.display = widget.showNext ? 'flex' : 'none';
  }

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

    final winW = html.window.innerWidth!.toDouble();
    final right = winW - (pos.dx + size.width);
    final cx = pos.dx + size.width / 2;
    final cy = pos.dy + size.height / 2;

    final c = _countdownEl?.style;
    if (c != null) {
      c
        ..left = ''
        ..top = '${pos.dy + 10}px'
        ..right = '${right + 12}px';
    }
    final r = _replayEl?.style;
    if (r != null) {
      r
        ..left = '${cx}px'
        ..top = '${cy}px'
        ..transform = 'translate(-50%, -50%)';
    }
    final n = _nextEl?.style;
    if (n != null) {
      n
        ..left = ''
        ..top = '${cy}px'
        ..right = '${right + 16}px'
        ..transform = 'translateY(-50%)';
    }
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
      _persistMuted(true);
      _cmd('mute', []);
      _applySound(false);
    } else {
      _mutedByUser = false;
      _persistMuted(false);
      _pageInteracted = true;
      _persistInteracted();
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

  // ── Updates ────────────────────────────────────────────────────────────────

  @override
  void didUpdateWidget(DirectYouTubePlayer old) {
    super.didUpdateWidget(old);
    if (widget.replayCount != old.replayCount) {
      _ended = false;
      _hasPlayed = false;
      _cmd('seekTo', [widget.startTime, true]);
      _cmd('playVideo', []);
    }
    if (widget.countdown != old.countdown ||
        widget.showCountdown != old.showCountdown ||
        widget.showReplay != old.showReplay ||
        widget.showNext != old.showNext) {
      _refreshOverlays();
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
    _countdownEl?.remove();
    _replayEl?.remove();
    _nextEl?.remove();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updatePosition());

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        key: _containerKey,
        color: Colors.black,
      ),
    );
  }
}
