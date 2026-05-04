import 'dart:convert';
import 'package:crypto/crypto.dart';

class SentenceHash {
  SentenceHash._();

  /// Produces the cache key for a given (wordId, transcription) pair.
  static String buildAiCacheKey(String wordId, String transcription) {
    final input = '$wordId|$transcription';
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}
