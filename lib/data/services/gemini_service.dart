import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/dictionary_model.dart';
import '../../core/errors/app_exception.dart';

class GeminiService {
  final GenerativeModel _model;

  GeminiService({required String apiKey})
      : _model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: apiKey,
        );

  Future<AiContextCache> explainWordInContext({
    required String simplified,
    required String transcription,
    required int hskLevel,
    required String userLanguage,
  }) async {
    final prompt = _buildPrompt(
      simplified: simplified,
      transcription: transcription,
      hskLevel: hskLevel,
      userLanguage: userLanguage,
    );

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      if (text.isEmpty) throw const GeminiApiException('Empty response from Gemini.');

      return AiContextCache(
        explanation: _parseSection(text, 'EXPLANATION') ?? text,
        grammarNote: _parseSection(text, 'GRAMMAR') ?? '',
        cachedAt: DateTime.now(),
      );
    } on GenerativeAIException catch (e) {
      throw GeminiApiException(e.message);
    }
  }

  String _buildPrompt({
    required String simplified,
    required String transcription,
    required int hskLevel,
    required String userLanguage,
  }) {
    final languageName = switch (userLanguage) {
      'tr' => 'Turkish',
      'vi' => 'Vietnamese',
      _ => 'English',
    };
    return '''
You are a Mandarin Chinese teacher. Explain the word "$simplified" as used in this sentence:

"$transcription"

Respond in $languageName. Be concise (max 100 words total). Use this format exactly:

EXPLANATION: [Meaning of "$simplified" in the context of the sentence above.]
GRAMMAR: [One grammar pattern or note about this word at HSK $hskLevel level.]
''';
  }

  String? _parseSection(String text, String sectionName) {
    final pattern = RegExp('$sectionName:\\s*(.+?)(?=\\n[A-Z]+:|\\s*\$)', dotAll: true);
    final match = pattern.firstMatch(text);
    return match?.group(1)?.trim();
  }
}
