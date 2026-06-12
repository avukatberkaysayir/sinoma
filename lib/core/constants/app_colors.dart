import 'package:flutter/material.dart';

// Ink palette (design identity), now theme-aware: `dark` is kept in sync by
// ThemeModeNotifier; every getter resolves to the ink (dark) or rice-paper
// (light) value. The old navy/red duo palette must not come back.
class AppColors {
  AppColors._();

  // Light (rice paper) is the app default; ThemeModeNotifier keeps this in
  // sync with the saved preference.
  static bool dark = false;

  static const Color primary = Color(0xFF2EC4B6);
  static const Color primaryDark = Color(0xFF21968B);

  // Page background / panel surfaces.
  static Color get surface =>
      dark ? const Color(0xFF0E1414) : const Color(0xFFF6F2E8);
  static Color get surfaceVariant =>
      dark ? const Color(0xFF161E1D) : const Color(0xFFFFFFFF);
  static Color get border =>
      dark ? const Color(0xFF263230) : const Color(0xFFE3DDD0);
  static Color get locked =>
      dark ? const Color(0xFF2E3A38) : const Color(0xFFD8D2C4);

  // Text ladder — the dark theme's Colors.white(NN) equivalents, mapped to
  // ink tones on rice paper.
  static Color get onSurface =>
      dark ? const Color(0xFFEEEEEE) : const Color(0xFF1A2422);
  static Color get onSurfaceMuted =>
      dark ? const Color(0xFF9E9E9E) : const Color(0xFF6B6B5E);
  static Color get text => onSurface;
  static Color get text70 =>
      dark ? Colors.white70 : const Color(0xB31A2422);
  static Color get text60 =>
      dark ? Colors.white60 : const Color(0x991A2422);
  static Color get text54 =>
      dark ? Colors.white54 : const Color(0x8A1A2422);
  static Color get text38 =>
      dark ? Colors.white38 : const Color(0x611A2422);
  static Color get text30 =>
      dark ? Colors.white30 : const Color(0x4D1A2422);
  static Color get text24 =>
      dark ? Colors.white24 : const Color(0x3D1A2422);
  static Color get text12 =>
      dark ? Colors.white12 : const Color(0x1F1A2422);
  static Color get text10 =>
      dark ? Colors.white10 : const Color(0x1A1A2422);

  static const Color hsk1 = Color(0xFF4CAF50);
  static const Color hsk2 = Color(0xFF8BC34A);
  static const Color hsk3 = Color(0xFFFFC107);
  static const Color hsk4 = Color(0xFFFF9800);
  static const Color hsk5 = Color(0xFFF44336);
  static const Color hsk6 = Color(0xFF9C27B0);

  static Color forHskLevel(int level) {
    switch (level) {
      case 1: return hsk1;
      case 2: return hsk2;
      case 3: return hsk3;
      case 4: return hsk4;
      case 5: return hsk5;
      case 6: return hsk6;
      default: return hsk1;
    }
  }

  static const Color correctAnswer = Color(0xFF4CAF50);
  static const Color wrongAnswer = Color(0xFFE63946);
  static const Color premiumGold = Color(0xFFFFD700);
}
