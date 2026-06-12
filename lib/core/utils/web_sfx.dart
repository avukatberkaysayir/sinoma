// Tiny WebAudio synth via JS interop — Sinoma's own audio identity (no
// assets): guzheng-like pentatonic pluck for a correct answer, a soft low
// thud for a wrong one, and a gong for completing something. Best-effort;
// audio must never break the flow.
import 'dart:js_interop';

@JS('AudioContext')
extension type _Ctx._(JSObject _) implements JSObject {
  external factory _Ctx();
  external _Osc createOscillator();
  external _Gain createGain();
  external JSObject get destination;
  external num get currentTime;
}

@JS()
extension type _Osc._(JSObject _) implements JSObject {
  external set type(String t);
  external _Param get frequency;
  external void connect(JSObject node);
  external void start(num when);
  external void stop(num when);
}

@JS()
extension type _Gain._(JSObject _) implements JSObject {
  external _Param get gain;
  external void connect(JSObject node);
}

@JS()
extension type _Param._(JSObject _) implements JSObject {
  external set value(num v);
  external void setValueAtTime(num value, num startTime);
  external void exponentialRampToValueAtTime(num value, num endTime);
}

class WebSfx {
  static _Ctx? _ctx;

  /// Global mute, toggled from the profile; persisted by sfxEnabledProvider.
  static bool enabled = true;

  static _Ctx? get _c {
    try {
      return _ctx ??= _Ctx();
    } catch (_) {
      return null;
    }
  }

  static void _tone(double freq, double dur,
      {String type = 'sine', double gain = 0.16, double when = 0}) {
    if (!enabled) return;
    final c = _c;
    if (c == null) return;
    try {
      final o = c.createOscillator();
      final g = c.createGain();
      o.type = type;
      o.frequency.value = freq;
      final t0 = c.currentTime + when;
      g.gain.setValueAtTime(gain, t0);
      g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
      o.connect(g as JSObject);
      g.connect(c.destination);
      o.start(t0);
      o.stop(t0 + dur);
    } catch (_) {/* ignore */}
  }

  /// Two-note pentatonic pluck (E5 → A5), guzheng-ish.
  static void correct() {
    _tone(659.3, 0.22);
    _tone(880.0, 0.30, when: 0.09);
  }

  /// Clearly audible descending two-note "dun-dun" (G3 → D3).
  static void wrong() {
    _tone(196.0, 0.18, type: 'triangle', gain: 0.32);
    _tone(146.8, 0.34, type: 'triangle', gain: 0.32, when: 0.13);
  }

  /// Gong: low fundamental with a long tail + a faint octave shimmer.
  static void gong() {
    _tone(196.0, 1.6, gain: 0.22);
    _tone(392.0, 1.1, gain: 0.06, when: 0.03);
  }
}
