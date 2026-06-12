// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';

// ── Controller ───────────────────────────────────────────────────────────────

class DirectYouTubeController extends ChangeNotifier {
  _DirectYouTubePlayerState? _state;
  // The chosen rate outlives a single iframe: each clip rebuilds the player, so
  // the new state re-applies it once playback starts.
  double _rate = 1.0;

  void _attach(_DirectYouTubePlayerState s) => _state = s;
  void _detach() => _state = null;

  bool get soundOn => _state?._soundOn ?? false;
  // Live playback state — inline panels pause only a PLAYING video and resume
  // only what they paused.
  bool get isPlaying => _state?._playing ?? false;
  void toggleSound() => _state?._toggleSound();
  void showScorePopup(int points) => _state?._showScorePopup(points);

  void pauseVideo() => _state?._cmd('pauseVideo', []);
  void playVideo() => _state?._cmd('playVideo', []);
  // The iframe is an HTML element ABOVE the Flutter canvas — any Flutter
  // dialog opened over the player would be hidden behind it. Hide the whole
  // player (iframe + overlays) while a dialog is up.
  void setHidden(bool hidden) => _state?._setHidden(hidden);
  void seekTo(double seconds) => _state?._cmd('seekTo', [seconds, true]);
  void setPlaybackRate(double rate) {
    _rate = rate;
    _state?._applyRate();
  }

  // Manual quality preference. YouTube treats this as a SUGGESTION (its ABR
  // can override it), but it works in many sessions — best effort by design.
  static const qualityLevels = ['small', 'medium', 'large', 'hd720', 'hd1080'];
  String _quality = 'large';
  String get quality => _quality;
  void setQuality(String q) {
    _quality = q;
    _state?._applyQuality();
  }

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
  // Watch-time chunks (whole seconds actually played) — badge ladder source.
  final ValueChanged<int>? onWatched;

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
    this.onWatched,
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
  // MUST reset to false on every page load: cold start = muted autoplay (the
  // only kind Chrome allows without user activation). Set true only after a
  // real interaction in THIS page session, so subsequent clips autoplay with
  // sound. Persisting it across loads would wrongly trigger unmuted autoplay
  // after a refresh — which Chrome blocks (no activation), so nothing plays.
  static bool _pageInteracted = false;
  static bool _mutedByUser = false;

  static const _gestureEvents = [
    'pointerdown', 'mousedown', 'keydown', 'touchstart', 'mousemove', 'wheel',
  ];
  static const _hardEvents = {
    'pointerdown', 'mousedown', 'keydown', 'touchstart',
  };

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
  // Wall-clock safety net: if the YouTube JS-API messages don't flow (so we
  // never see currentTime), end the segment after its duration + a generous
  // buffer. While currentTime DOES flow, _handleTime continuously reschedules
  // this to "remaining time + buffer", so slow networks / buffering pauses can
  // never cut a clip short.
  Timer? _endFallbackTimer;
  // Cold-start recovery: if autoplay didn't take (no playback within a few
  // seconds), nudge playVideo + the listening handshake until it does.
  Timer? _nudgeTimer;
  int _nudgeTries = 0;

  bool _soundOn = false;
  bool _hasPlayed = false;
  bool _ended = false;
  bool _playing = false; // YouTube playerState == 1
  DateTime _lastUnmuteTry = DateTime.fromMillisecondsSinceEpoch(0);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);

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
      if (_hardEvents.contains(e.type)) _pageInteracted = true;
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

    frame.onLoad.listen((_) {
      _startListening();
      _armEndFallback();
      _startNudge();
    });

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
    if (_hidden) return; // keep everything invisible while a dialog is up
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

  bool _hidden = false;

  void _setHidden(bool h) {
    _hidden = h;
    _iframe?.style.visibility = h ? 'hidden' : '';
    if (h) {
      _countdownEl?.style.display = 'none';
      _replayEl?.style.display = 'none';
      _nextEl?.style.display = 'none';
      _cmd('pauseVideo', []);
      // The clip is intentionally paused: the wall-clock fallback must not
      // keep counting down while nothing plays.
      _endFallbackTimer?.cancel();
    } else {
      _refreshOverlays();
      if (!_ended) _armEndFallback();
    }
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
      _applyRate();
      _applyQuality();
    } else if (event == 'infoDelivery') {
      _eventsFlowing = true;
      _listenTimer?.cancel();

      final info = data['info'];
      if (info is Map) {
        final state = (info['playerState'] as num?)?.toInt();
        if (state != null) _playing = state == 1;
        if (state == 1) _markPlaying();

        final muted = info['muted'];
        final volume = (info['volume'] as num?)?.toInt();
        if (muted is bool) {
          _applySound(!muted && (volume == null || volume > 0));
        }

        // YouTube resets the rate on (re)load; push the chosen one back as soon
        // as a mismatch shows up in the info stream.
        final rate = (info['playbackRate'] as num?)?.toDouble();
        if (rate != null && (rate - widget.controller._rate).abs() > 0.01) {
          _applyRate();
        }

        // Process time even before a playerState==1 arrives — on some setups
        // currentTime flows while state messages don't, and without this the clip
        // would never reach its end. _handleTime guards t<=0 / pre-start anyway.
        final t = (info['currentTime'] as num?)?.toDouble();
        if (t != null) _handleTime(t);
      }
    } else if (event == 'onStateChange') {
      final state = (data['info'] as num?)?.toInt();
      if (state != null) _playing = state == 1;
      if (state == 1) _markPlaying();
    }
  }

  void _markPlaying() {
    _applyRate();
    if (_hasPlayed) return;
    _hasPlayed = true;
  }

  // Send the controller's playback rate to the iframe. Called when the user
  // picks a speed AND whenever playback (re)starts — a command sent before the
  // player is ready is silently dropped, so a one-shot send never sticks.
  void _applyRate() {
    final r = widget.controller._rate;
    if (r > 0) _cmd('setPlaybackRate', [r]);
  }

  // Watch-time accumulator: currentTime ticks arrive continuously while the
  // clip plays; sum forward deltas and flush in ~20s chunks (+ on dispose).
  double? _lastTickT;
  double _watchAcc = 0;

  void _accumulateWatch(double t) {
    final last = _lastTickT;
    _lastTickT = t;
    if (last == null) return;
    final dt = t - last;
    if (dt <= 0 || dt > 3) return; // seek/jump — not real watching
    _watchAcc += dt;
    if (_watchAcc >= 20) _flushWatch();
  }

  void _flushWatch() {
    final s = _watchAcc.floor();
    if (s <= 0) return;
    _watchAcc -= s;
    widget.onWatched?.call(s);
  }

  void _handleTime(double t) {
    if (t <= 0) return;
    _accumulateWatch(t);
    if (_playing) _rescheduleEndFallback(t);

    if (t >= widget.endTime) {
      // Hard ceiling: even if the segment already "ended" once (e.g. an inline
      // panel paused/resumed playback), the clip must NEVER run past its end.
      if (!_ended) {
        _forceEnd();
      } else if (_playing) {
        _playing = false;
        _cmd('pauseVideo', []);
      }
      return;
    }

    if (t < widget.startTime - 1) {
      _cmd('seekTo', [widget.startTime, true]);
    }
  }

  // Stop the clip at its segment end (from accurate currentTime OR the fallback
  // timer). Idempotent.
  void _forceEnd() {
    if (_ended) return;
    _ended = true;
    _playing = false;
    _endFallbackTimer?.cancel();
    _cmd('pauseVideo', []);
    if (mounted) widget.onSegmentEnded();
  }

  void _armEndFallback() {
    _endFallbackTimer?.cancel();
    final rate = widget.controller._rate > 0 ? widget.controller._rate : 1.0;
    final dur = (widget.endTime - widget.startTime) / rate;
    if (dur <= 0) return;
    // Generous initial window (load + buffering). As soon as currentTime
    // flows, _handleTime keeps rescheduling to "remaining + 6s", so this can
    // only fire when playback is truly broken — never mid-clip on a slow
    // connection.
    _endFallbackTimer =
        Timer(Duration(milliseconds: ((dur + 12) * 1000).round()), _forceEnd);
  }

  // Progress-anchored fallback: every currentTime tick moves the deadline to
  // remaining-time + buffer. Buffering pauses simply stop the ticks AND the
  // deadline stops shrinking relative to actual progress made so far.
  void _rescheduleEndFallback(double currentT) {
    if (_ended) return;
    _endFallbackTimer?.cancel();
    final rate = widget.controller._rate > 0 ? widget.controller._rate : 1.0;
    final remaining = (widget.endTime - currentT) / rate;
    if (remaining <= 0) return;
    _endFallbackTimer = Timer(
        Duration(milliseconds: ((remaining + 6) * 1000).round()), _forceEnd);
  }

  // Cold-start recovery: hard refresh sometimes leaves the iframe sitting on
  // YouTube's play button (autoplay raced the JS-API handshake). Until real
  // playback is seen, periodically resend the handshake + playVideo. Stops on
  // first playback so it can never fight a user's manual pause.
  void _startNudge() {
    _nudgeTimer?.cancel();
    _nudgeTries = 0;
    _nudgeTimer = Timer.periodic(const Duration(seconds: 3), (t) {
      if (!mounted || _hasPlayed || _ended || _hidden || _nudgeTries++ > 10) {
        t.cancel();
        return;
      }
      _sendListening();
      _cmd('playVideo', []);
    });
  }

  void _applyQuality() {
    _cmd('setPlaybackQuality', [widget.controller._quality]);
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
      _lastTickT = null;
      _cmd('seekTo', [widget.startTime, true]);
      _cmd('playVideo', []);
      _applyRate();
      _armEndFallback();
      _startNudge();
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
    _flushWatch();
    widget.controller._detach();
    _listenTimer?.cancel();
    _endFallbackTimer?.cancel();
    _nudgeTimer?.cancel();
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
