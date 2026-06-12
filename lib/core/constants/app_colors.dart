import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Ink palette (design identity): deep ink background, panel, turquoise
  // accent. The old navy/red duo palette must not come back.
  static const Color primary = Color(0xFF2EC4B6);
  static const Color primaryDark = Color(0xFF21968B);
  static const Color surface = Color(0xFF0E1414);
  static const Color surfaceVariant = Color(0xFF161E1D);
  static const Color onSurface = Color(0xFFEEEEEE);
  static const Color onSurfaceMuted = Color(0xFF9E9E9E);

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
