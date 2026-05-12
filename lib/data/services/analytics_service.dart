// Analytics are handled via Vercel Analytics (injected in index.html).
// This service is a no-op stub — all method signatures are preserved so call
// sites compile without changes.
class AnalyticsService {
  Future<void> identifyUser(String uid,
      {int? hskLevel, bool? isPremium}) async {}

  Future<void> logSignIn(String method) async {}

  Future<void> logOnboardingCompleted(int hskLevel) async {}

  Future<void> logVideoStarted(String videoId, int hskLevel) async {}

  Future<void> logVideoCompleted({
    required String videoId,
    required int hskLevel,
    required bool wasCorrect,
    required String quizCategory,
  }) async {}

  Future<void> logAiExplanationRequested({
    required String wordId,
    required int hskLevel,
    required bool wasCached,
  }) async {}

  Future<void> logGameStarted(String gameType, int hskLevel) async {}

  Future<void> logGameCompleted({
    required String gameType,
    required int hskLevel,
    required int score,
    required int roundsPlayed,
    required bool survived,
  }) async {}

  Future<void> logRewardedAdWatched(String reason) async {}

  Future<void> logSubscriptionScreenViewed() async {}
}
