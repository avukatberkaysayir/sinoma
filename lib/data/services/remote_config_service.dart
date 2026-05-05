import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  final _rc = FirebaseRemoteConfig.instance;

  static const _defaults = <String, dynamic>{
    'interstitial_frequency_first': 20,
    'interstitial_frequency_repeat': 10,
    'ai_credits_daily_free': 5,
    'max_ai_credits': 50,
    'min_hsk_videos_required': 20,
    'min_learned_words_required': 50,
    'placement_test_enabled': true,
    'rewarded_ad_credits_amount': 10,
    'hanzi_build_enabled': true,
    'social_feed_enabled': true,
  };

  Future<void> initialize() async {
    await _rc.setDefaults(_defaults);
    await _rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    try {
      await _rc.fetchAndActivate();
    } catch (_) {
      // Network failure — defaults remain active, safe to continue.
    }
  }

  int get interstitialFrequencyFirst =>
      _rc.getInt('interstitial_frequency_first');
  int get interstitialFrequencyRepeat =>
      _rc.getInt('interstitial_frequency_repeat');
  int get aiCreditsDailyFree => _rc.getInt('ai_credits_daily_free');
  int get maxAiCredits => _rc.getInt('max_ai_credits');
  int get minHskVideosRequired => _rc.getInt('min_hsk_videos_required');
  int get minLearnedWordsRequired => _rc.getInt('min_learned_words_required');
  bool get placementTestEnabled => _rc.getBool('placement_test_enabled');
  int get rewardedAdCreditsAmount => _rc.getInt('rewarded_ad_credits_amount');
  bool get hanziBuildEnabled => _rc.getBool('hanzi_build_enabled');
  bool get socialFeedEnabled => _rc.getBool('social_feed_enabled');
}
