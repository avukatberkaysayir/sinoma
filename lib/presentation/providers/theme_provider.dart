import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';

const _kKey = 'theme_is_dark';

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  // Light (rice paper) is the DEFAULT; dark ink is the opt-in.
  ThemeModeNotifier() : super(ThemeMode.light) {
    AppColors.dark = false;
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_kKey) ?? false;
    AppColors.dark = isDark; // palette getters resolve per theme
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggleTheme() async {
    final nowDark = state == ThemeMode.dark;
    AppColors.dark = !nowDark;
    state = nowDark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKey, !nowDark);
  }

  bool get isDark => state == ThemeMode.dark;
}
