// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// ignore_for_file: non_constant_identifier_names
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';

// ── Official YouTube IFrame Player API bindings ──────────────────────────────
// We drive playback through Google's documented YT.Player (loaded from
// https://www.youtube.com/iframe_api), not a hand-rolled postMessage protocol —
// every call below is a published API method, satisfying the YouTube API
// Services "don't change the player beyond the documented API" requirement.

@JS('YT.Player')
extension type _YTPlayer._(JSObject _) implements JSObject {
  external factory _YTPlayer(JSString id, _PlayerOptions options);
  external void playVideo();
  external void pauseVideo();
  external void seekTo(num seconds, bool allowSeekAhead);
  external void setPlaybackRate(num rate);
  external void setPlaybackQuality(String quality);
  external void mute();
  external void unMute();
  external void setVolume(num volume);
  external void unloadModule(String module);
  external double getCurrentTime();
  external int getPlayerState();
  external double getPlaybackRate();
  external bool isMuted();
  external double getVolume();
  external void destroy();
}

extension type _PlayerOptions._(JSObject _) implements JSObject {
  external factory _PlayerOptions({
    String width,
    String height,
    String videoId,
    _PlayerVars playerVars,
    _Events events,
  });
}

extension type _PlayerVars._(JSObject _) implements JSObject {
  external factory _PlayerVars({
    int autoplay,
    int controls,
    int rel,
    int playsinline,
    int mute,
    int start,
    int cc_load_policy,
    int iv_load_policy,
    String origin,
  });
}

extension type _Events._(JSObject _) implements JSObject {
  external factory _Events({
    JSFunction onReady,
    JSFunction onStateChange,
    JSFunction onError,
  });
}

extension type _YTEvent._(JSObject _) implements JSObject {
  external JSAny? get data;
}

// Load the iframe API exactly once; resolve when YT.Player is constructible.
Completer<void>? _ytReady;
Future<void> _ensureYouTubeApi() {
  if (globalContext.has('YT')) {
    final yt = globalContext['YT'] as JSObject?;
    if (yt != null && yt.has('Player')) return Future.value();
  }
  if (_ytReady != null) return _ytReady!.future;
  final c = _ytReady = Completer<void>();
  globalContext['onYouTubeIframeAPIReady'] = (() {
    if (!c.isCompleted) c.complete();
  }).toJS;
  if (html.document.querySelector('script[src*="iframe_api"]') == null) {
    html.document.head!.append(html.ScriptElement()
      ..src = 'https://www.youtube.com/iframe_api'
      ..async = true);
  }
  return c.future;
}

// ── Controller ───────────────────────────────────────────────────────────────

class DirectYouTubeController extends ChangeNotifier {
  _DirectYouTubePlayerState? _state;
  // The chosen rate outlives a single player: each clip rebuilds it, so the new
  // state re-applies the rate once playback starts.
  double _rate = 1.0;

  void _attach(_DirectYouTubePlayerState s) => _state = s;
  void _detach() => _state = null;

  bool get soundOn => _state?._soundOn ?? false;
  // Live playback state — inline panels pause only a PLAYING video and resume
  // only what they paused.
  bool get isPlaying => _state?._playing ?? false;
  void toggleSound() => _state?._toggleSound();

  void pauseVideo() => _state?._player?.pauseVideo();
  void playVideo() => _state?._player?.playVideo();
  // The player iframe sits ABOVE the Flutter canvas — a Flutter dialog opened
  // over it would be hidden behind it. Hide the whole player while a dialog is up.
  void setHidden(bool hidden) => _state?._setHidden(hidden);
  void seekTo(double seconds) => _state?._player?.seekTo(seconds, true);
  void setPlaybackRate(double rate) {
    _rate = rate;
    _state?._applyRate();
  }

  // Manual quality preference. YouTube treats this as a SUGGESTION (its ABR can
  // override it), but it works in many sessions — best effort by design.
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
  final int replayCount;
  final DirectYouTubeController controller;
  final VoidCallback onSegmentEnded;
  final ValueChanged<bool>? onSoundChanged;
  // Watch-time chunks (whole seconds actually played) — badge ladder source.
  final ValueChanged<int>? onWatched;
  // YouTube refused to embed this video (codes 100/101/150/5/2) — the parent
  // should skip the clip rather than show a dead player.
  final VoidCallback? onEmbedError;

  const DirectYouTubePlayer({
    super.key,
    required this.videoId,
    required this.startTime,
    required this.endTime,
    required this.replayCount,
    required this.controller,
    required this.onSegmentEnded,
    this.onSoundChanged,
    this.onWatched,
    this.onEmbedError,
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
  static int _seq = 0; // unique container ids

  static const _gestureEvents = [
    'pointerdown', 'mousedown', 'keydown', 'touchstart', 'mousemove', 'wheel',
  ];
  static const _hardEvents = {
    'pointerdown', 'mousedown', 'keydown', 'touchstart',
  };

  final GlobalKey _containerKey = GlobalKey();

  _YTPlayer? _player;
  html.DivElement? _outer; // fixed-positioned host we control the geometry of
  late final String _playerId;
  html.EventListener? _gestureListener;
  // Autoplay compliance: YouTube requires an automatic playback start only once
  // more than half of the player is visible. We watch scroll/resize until the
  // embed is mostly on-screen, then create the player (which autoplays).
  html.EventListener? _visListener;

  Timer? _ticker; // polls getCurrentTime/state (official API has no time event)
  // Wall-clock safety net: if playback never reports progress, end the segment
  // after its duration + a generous buffer. While currentTime advances,
  // _handleTime continuously reschedules this to "remaining + buffer", so slow
  // networks / buffering pauses can never cut a clip short.
  Timer? _endFallbackTimer;
  // Cold-start recovery: if autoplay didn't take (no playback within a few
  // seconds), nudge playVideo until it does.
  Timer? _nudgeTimer;
  int _nudgeTries = 0;

  bool _soundOn = false;
  bool _hasPlayed = false;
  bool _ended = false;
  bool _playing = false; // YouTube playerState == 1
  bool _embedFailed = false;
  DateTime _lastUnmuteTry = DateTime.fromMillisecondsSinceEpoch(0);

  // Kept alive so the JS side holds stable function references.
  late final JSFunction _jsOnReady = ((JSObject _) => _onReady()).toJS;
  late final JSFunction _jsOnState = ((JSObject e) => _onState(e)).toJS;
  late final JSFunction _jsOnError = ((JSObject e) => _onError(e)).toJS;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    _playerId = 'sinoma-yt-${_seq++}';

    _gestureListener = (e) {
      if (_hardEvents.contains(e.type)) _pageInteracted = true;
      _tryUnmute();
    };
    for (final type in _gestureEvents) {
      html.document.addEventListener(type, _gestureListener!, true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _armVisibilityGate();
    });
  }

  // ── Autoplay visibility gate ─────────────────────────────────────────────────
  void _armVisibilityGate() {
    if (_isMostlyVisible()) {
      _createPlayer();
      return;
    }
    _visListener ??= (_) {
      if (_outer != null) return;
      if (_isMostlyVisible()) {
        _createPlayer();
        _removeVisibilityGate();
      }
    };
    html.window.addEventListener('scroll', _visListener!, true);
    html.window.addEventListener('resize', _visListener!);
  }

  void _removeVisibilityGate() {
    if (_visListener == null) return;
    html.window.removeEventListener('scroll', _visListener!, true);
    html.window.removeEventListener('resize', _visListener!);
    _visListener = null;
  }

  bool _isMostlyVisible() {
    final box = _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final pos = box.localToGlobal(Offset.zero);
    final h = box.size.height;
    if (h <= 0) return false;
    final winH = html.window.innerHeight!.toDouble();
    final top = pos.dy.clamp(0.0, winH);
    final bottom = (pos.dy + h).clamp(0.0, winH);
    return (bottom - top) >= h * 0.5;
  }

  // ── Player creation ──────────────────────────────────────────────────────────

  void _createPlayer() {
    if (_outer != null) return;

    final muted = !_pageInteracted || _mutedByUser;
    _soundOn = !muted;

    // Outer host carries the fixed geometry; YT replaces the inner div with the
    // iframe, which fills the host at 100%.
    final inner = html.DivElement()..id = _playerId;
    final outer = html.DivElement()
      ..style.position = 'fixed'
      ..style.zIndex = '5'
      ..style.overflow = 'hidden'
      ..append(inner);
    _outer = outer;
    html.document.body!.append(outer);
    _applyGeometry();

    final origin = html.window.location.origin;

    _ensureYouTubeApi().then((_) {
      if (!mounted || _outer == null) return;
      _player = _YTPlayer(
        _playerId.toJS,
        _PlayerOptions(
          width: '100%',
          height: '100%',
          videoId: widget.videoId,
          playerVars: _PlayerVars(
            autoplay: 1,
            controls: 0,
            rel: 0,
            playsinline: 1,
            mute: muted ? 1 : 0,
            start: widget.startTime.toInt(),
            cc_load_policy: 0,
            iv_load_policy: 3,
            origin: origin,
          ),
          events: _Events(
            onReady: _jsOnReady,
            onStateChange: _jsOnState,
            onError: _jsOnError,
          ),
        ),
      );
      _armEndFallback();
      _startNudge();
    });

    widget.controller._notify();
  }

  void _applyGeometry() {
    final box = _containerKey.currentContext?.findRenderObject() as RenderBox?;
    final style = _outer?.style;
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

  bool _hidden = false;

  void _setHidden(bool h) {
    _hidden = h;
    _outer?.style.visibility = h ? 'hidden' : '';
    if (h) {
      _safe(() => _player?.pauseVideo());
      // Intentionally paused: the wall-clock fallback must not keep counting
      // down while nothing plays.
      _endFallbackTimer?.cancel();
    } else if (!_ended) {
      _armEndFallback();
    }
  }

  // ── Sound ────────────────────────────────────────────────────────────────

  void _tryUnmute() {
    if (_soundOn || _mutedByUser) return;
    final now = DateTime.now();
    if (now.difference(_lastUnmuteTry).inMilliseconds < 400) return;
    _lastUnmuteTry = now;
    _safe(() {
      _player?.unMute();
      _player?.setVolume(100);
    });
  }

  void _toggleSound() {
    if (_soundOn) {
      _mutedByUser = true;
      _safe(() => _player?.mute());
      _applySound(false);
    } else {
      _mutedByUser = false;
      _pageInteracted = true;
      _lastUnmuteTry = DateTime.fromMillisecondsSinceEpoch(0);
      _safe(() {
        _player?.unMute();
        _player?.setVolume(100);
      });
      _applySound(true);
    }
  }

  void _applySound(bool on) {
    if (_soundOn == on) return;
    _soundOn = on;
    widget.controller._notify();
    widget.onSoundChanged?.call(on);
  }

  // ── Player events ──────────────────────────────────────────────────────────

  void _onReady() {
    _safe(() {
      _player?.playVideo();
      _disableYtCaptions();
    });
    _applyRate();
    _applyQuality();
    _startTicker();
  }

  void _onState(JSObject event) {
    final state = _eventInt(event);
    if (state == null) return;
    _playing = state == 1;
    if (state == 1) _markPlaying();
  }

  void _onError(JSObject event) {
    // 2 invalid id · 5 HTML5 error · 100 removed/private · 101 & 150 embedding
    // disabled by the owner. Any of these means we can't play it — skip.
    final code = _eventInt(event);
    if (code != null && {2, 5, 100, 101, 150}.contains(code)) {
      _handleEmbedError();
    }
  }

  int? _eventInt(JSObject event) {
    final d = (event as _YTEvent).data;
    if (d != null && d.isA<JSNumber>()) return (d as JSNumber).toDartInt;
    return null;
  }

  void _handleEmbedError() {
    if (_embedFailed) return;
    _embedFailed = true;
    _endFallbackTimer?.cancel();
    _nudgeTimer?.cancel();
    if (mounted) widget.onEmbedError?.call();
  }

  void _markPlaying() {
    _applyRate();
    // Re-kill YouTube's captions on every (re)start: the player restores the
    // viewer's saved CC preference when a new clip cues.
    _disableYtCaptions();
    if (_hasPlayed) return;
    _hasPlayed = true;
  }

  // Our own subtitles render below the player; YouTube's burned-in captions
  // would double them up, so unload the caption modules outright.
  void _disableYtCaptions() {
    _safe(() {
      _player?.unloadModule('captions');
      _player?.unloadModule('cc');
    });
  }

  void _applyRate() {
    final r = widget.controller._rate;
    if (r > 0) _safe(() => _player?.setPlaybackRate(r));
  }

  void _applyQuality() {
    _safe(() => _player?.setPlaybackQuality(widget.controller._quality));
  }

  // ── Progress ticker (replaces the postMessage infoDelivery stream) ───────────

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final p = _player;
      if (p == null) return;
      double t;
      try {
        t = p.getCurrentTime();
        _playing = p.getPlayerState() == 1;
        // YouTube resets the rate on (re)load; push the chosen one back when a
        // mismatch shows up.
        final r = p.getPlaybackRate();
        if ((r - widget.controller._rate).abs() > 0.01) _applyRate();
        // Reflect the real mute/volume state back to the UI.
        _applySound(!p.isMuted() && p.getVolume() > 0);
      } catch (_) {
        return; // player not ready / mid-teardown
      }
      _handleTime(t);
    });
  }

  // Watch-time accumulator: ticks arrive continuously while the clip plays; sum
  // forward deltas and flush in ~20s chunks (+ on dispose).
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
        _safe(() => _player?.pauseVideo());
      }
      return;
    }

    if (t < widget.startTime - 1) {
      _safe(() => _player?.seekTo(widget.startTime, true));
    }
  }

  // Stop the clip at its segment end (from currentTime OR the fallback timer).
  // Idempotent.
  void _forceEnd() {
    if (_ended) return;
    _ended = true;
    _playing = false;
    _endFallbackTimer?.cancel();
    _safe(() => _player?.pauseVideo());
    if (mounted) widget.onSegmentEnded();
  }

  void _armEndFallback() {
    _endFallbackTimer?.cancel();
    final rate = widget.controller._rate > 0 ? widget.controller._rate : 1.0;
    final dur = (widget.endTime - widget.startTime) / rate;
    if (dur <= 0) return;
    _endFallbackTimer =
        Timer(Duration(milliseconds: ((dur + 12) * 1000).round()), _forceEnd);
  }

  void _rescheduleEndFallback(double currentT) {
    if (_ended) return;
    _endFallbackTimer?.cancel();
    final rate = widget.controller._rate > 0 ? widget.controller._rate : 1.0;
    final remaining = (widget.endTime - currentT) / rate;
    if (remaining <= 0) return;
    _endFallbackTimer = Timer(
        Duration(milliseconds: ((remaining + 6) * 1000).round()), _forceEnd);
  }

  // Cold-start recovery: hard refresh sometimes leaves the player sitting on
  // YouTube's play button (autoplay raced the API). Until real playback is seen,
  // periodically resend playVideo. Stops on first playback so it can never fight
  // a user's manual pause.
  void _startNudge() {
    _nudgeTimer?.cancel();
    _nudgeTries = 0;
    _nudgeTimer = Timer.periodic(const Duration(seconds: 3), (t) {
      if (!mounted || _hasPlayed || _ended || _hidden || _nudgeTries++ > 10) {
        t.cancel();
        return;
      }
      _safe(() => _player?.playVideo());
    });
  }

  // YT methods throw if called before the player is ready or during teardown;
  // every call is best-effort.
  void _safe(void Function() fn) {
    try {
      fn();
    } catch (_) {/* ignore */}
  }

  // ── Updates ────────────────────────────────────────────────────────────────

  @override
  void didUpdateWidget(DirectYouTubePlayer old) {
    super.didUpdateWidget(old);
    if (widget.replayCount != old.replayCount) {
      _ended = false;
      _hasPlayed = false;
      _lastTickT = null;
      _safe(() {
        _player?.seekTo(widget.startTime, true);
        _player?.playVideo();
      });
      _applyRate();
      _armEndFallback();
      _startNudge();
    }
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    // DOM teardown FIRST and unconditionally: if anything later throws, the
    // player must already be gone — a leaked fixed-position iframe floats over
    // every other tab.
    _safe(() => _player?.destroy());
    _outer?.remove();
    try {
      _flushWatch();
    } catch (_) {/* stats are best-effort */}
    widget.controller._detach();
    _ticker?.cancel();
    _endFallbackTimer?.cancel();
    _nudgeTimer?.cancel();
    _removeVisibilityGate();
    if (_gestureListener != null) {
      for (final type in _gestureEvents) {
        html.document.removeEventListener(type, _gestureListener!, true);
      }
    }
    _outer?.remove();
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
