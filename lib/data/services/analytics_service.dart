import 'dart:js_interop';

// Vercel Analytics — page views tracked automatically via /_vercel/insights/script.js.
// Custom events use window.va('event', name, data) — available on Vercel Pro.
// On free tier va() is undefined; the try/catch silently swallows the call.

@JS('va')
external void _va(String type, String name, [JSAny? data]);

class AnalyticsService {
  void _track(String name, [Map<String, dynamic>? props]) {
    try {
      _va('event', name, props?.jsify());
    } catch (_) {}
  }

  Future<void> identifyUser(String uid,
      {int? hskLevel, bool? isPremium}) async {}

  Future<void> logSignIn(String method) async =>
      _track('sign_in', {'method': method});

  Future<void> logOnboardingCompleted(int hskLevel) async =>
      _track('onboarding_completed', {'hsk_level': hskLevel});

  Future<void> logVideoStarted(String videoId, int hskLevel) async =>
      _track('video_started', {'video_id': videoId, 'hsk_level': hskLevel});

  Future<void> logVideoCompleted({
    required String videoId,
    required int hskLevel,
    required bool wasCorrect,
    required String quizCategory,
  }) async =>
      _track('video_completed', {
        'video_id': videoId,
        'hsk_level': hskLevel,
        'correct': wasCorrect,
        'category': quizCategory,
      });

  Future<void> logAiExplanationRequested({
    required String wordId,
    required int hskLevel,
    required bool wasCached,
  }) async =>
      _track('ai_explanation', {
        'word_id': wordId,
        'hsk_level': hskLevel,
        'cached': wasCached,
      });

  Future<void> logGameStarted(String gameType, int hskLevel) async =>
      _track('game_started', {'game_type': gameType, 'hsk_level': hskLevel});

  Future<void> logGameCompleted({
    required String gameType,
    required int hskLevel,
    required int score,
    required int roundsPlayed,
    required bool survived,
  }) async =>
      _track('game_completed', {
        'game_type': gameType,
        'hsk_level': hskLevel,
        'score': score,
        'rounds': roundsPlayed,
        'survived': survived,
      });

  Future<void> logRewardedAdWatched(String reason) async =>
      _track('rewarded_ad', {'reason': reason});

  Future<void> logSubscriptionScreenViewed() async =>
      _track('subscription_screen_viewed');
}
