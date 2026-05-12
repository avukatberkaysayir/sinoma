class AppConfig {
  AppConfig._();

  /// Injected at build time: flutter run --dart-define=GEMINI_API_KEY=your_key
  /// In CI/CD: add as a Vercel environment variable and pass via --dart-define.
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static bool get hasGeminiKey => geminiApiKey.isNotEmpty;
}
