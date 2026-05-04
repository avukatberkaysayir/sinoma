sealed class AppException implements Exception {
  final String message;
  const AppException(this.message);
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'No internet connection.']);
}

class FirestoreException extends AppException {
  final String code;
  const FirestoreException(this.code, super.message);
}

class AiQuotaExceededException extends AppException {
  const AiQuotaExceededException()
      : super('AI credit quota exceeded. Watch an ad or upgrade to Pro.');
}

class GeminiApiException extends AppException {
  const GeminiApiException([super.message = 'Gemini API call failed.']);
}

class AuthException extends AppException {
  const AuthException([super.message = 'Authentication failed.']);
}

class VideoLoadException extends AppException {
  const VideoLoadException([super.message = 'Failed to load video segment.']);
}
