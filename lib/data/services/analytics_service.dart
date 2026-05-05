import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class AnalyticsService {
  final _analytics = FirebaseAnalytics.instance;
  final _crashlytics = FirebaseCrashlytics.instance;

  // ── Identity ──────────────────────────────────────────────────

  Future<void> identifyUser(String uid, {int? hskLevel, bool? isPremium}) async {
    await _crashlytics.setUserIdentifier(uid);
    await _analytics.setUserId(id: uid);
    if (hskLevel != null) {
      await _analytics.setUserProperty(name: 'hsk_level', value: '$hskLevel');
      await _crashlytics.setCustomKey('hsk_level', hskLevel);
    }
    if (isPremium != null) {
      await _analytics.setUserProperty(
          name: 'is_premium', value: isPremium ? '1' : '0');
    }
  }

  // ── Onboarding ────────────────────────────────────────────────

  Future<void> logSignIn(String method) async {
    await _analytics.logLogin(loginMethod: method);
  }

  Future<void> logOnboardingCompleted(int hskLevel) async {
    await _analytics.logEvent(
      name: 'onboarding_completed',
      parameters: {'hsk_level': hskLevel},
    );
    await _analytics.setUserProperty(name: 'hsk_level', value: '$hskLevel');
  }

  // ── Video ─────────────────────────────────────────────────────

  Future<void> logVideoStarted(String videoId, int hskLevel) async {
    await _analytics.logEvent(
      name: 'video_started',
      parameters: {'video_id': videoId, 'hsk_level': hskLevel},
    );
  }

  Future<void> logVideoCompleted({
    required String videoId,
    required int hskLevel,
    required bool wasCorrect,
    required String quizCategory,
  }) async {
    await _analytics.logEvent(
      name: 'video_completed',
      parameters: {
        'video_id': videoId,
        'hsk_level': hskLevel,
        'was_correct': wasCorrect ? 1 : 0,
        'quiz_category': quizCategory,
      },
    );
  }

  // ── AI Dictionary ─────────────────────────────────────────────

  Future<void> logAiExplanationRequested({
    required String wordId,
    required int hskLevel,
    required bool wasCached,
  }) async {
    await _analytics.logEvent(
      name: 'ai_explanation_used',
      parameters: {
        'word_id': wordId,
        'hsk_level': hskLevel,
        'was_cached': wasCached ? 1 : 0,
      },
    );
  }

  // ── Games ─────────────────────────────────────────────────────

  Future<void> logGameStarted(String gameType, int hskLevel) async {
    await _analytics.logEvent(
      name: 'game_started',
      parameters: {'game_type': gameType, 'hsk_level': hskLevel},
    );
  }

  Future<void> logGameCompleted({
    required String gameType,
    required int hskLevel,
    required int score,
    required int roundsPlayed,
    required bool survived,
  }) async {
    await _analytics.logEvent(
      name: 'game_completed',
      parameters: {
        'game_type': gameType,
        'hsk_level': hskLevel,
        'score': score,
        'rounds_played': roundsPlayed,
        'survived': survived ? 1 : 0,
      },
    );
  }

  // ── Monetization ──────────────────────────────────────────────

  Future<void> logRewardedAdWatched(String reason) async {
    await _analytics.logEvent(
      name: 'rewarded_ad_watched',
      parameters: {'reason': reason},
    );
  }

  Future<void> logSubscriptionScreenViewed() async {
    await _analytics.logScreenView(screenName: 'subscription');
  }

  // ── HSK Progression ───────────────────────────────────────────

  Future<void> logLevelUp(int newLevel) async {
    await _analytics.logEvent(
      name: 'hsk_level_up',
      parameters: {'new_level': newLevel},
    );
    await _analytics.setUserProperty(name: 'hsk_level', value: '$newLevel');
    await _crashlytics.setCustomKey('hsk_level', newLevel);
  }

  // ── Errors ────────────────────────────────────────────────────

  void recordNonFatalError(Object error, StackTrace stack, {String? reason}) {
    _crashlytics.recordError(error, stack, reason: reason, fatal: false);
  }
}
