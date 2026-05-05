class AppConfig {
  AppConfig._();

  /// Injected at build time: flutter run --dart-define=GEMINI_API_KEY=your_key
  /// In CI/CD: add to Fastlane lane as --dart-define or via firebase_options.
  /// Production hardening: proxy Gemini through Cloud Functions (ADIM 11).
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static bool get hasGeminiKey => geminiApiKey.isNotEmpty;
}
