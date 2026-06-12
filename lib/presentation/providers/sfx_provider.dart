import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/web_sfx.dart';

const _kSfxKey = 'sfx_enabled';

// Sound effects on/off — the profile toggle. Mirrors into WebSfx.enabled so
// the synth itself stays a plain static helper.
final sfxEnabledProvider =
    StateNotifierProvider<SfxNotifier, bool>((ref) => SfxNotifier());

class SfxNotifier extends StateNotifier<bool> {
  SfxNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final on = prefs.getBool(_kSfxKey) ?? true;
    WebSfx.enabled = on;
    if (mounted) state = on;
  }

  Future<void> toggle() async {
    final on = !state;
    state = on;
    WebSfx.enabled = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSfxKey, on);
  }
}
