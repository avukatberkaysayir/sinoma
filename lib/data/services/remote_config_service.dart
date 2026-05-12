// Remote Config replaced with hardcoded constants.
// Values can be tuned here and re-deployed without a backend change.
class RemoteConfigService {
  Future<void> initialize() async {}

  int get interstitialFrequencyFirst => 20;
  int get interstitialFrequencyRepeat => 10;
  int get aiCreditsDailyFree => 5;
  int get maxAiCredits => 50;
  int get minHskVideosRequired => 20;
  int get minLearnedWordsRequired => 50;
  bool get placementTestEnabled => true;
  int get rewardedAdCreditsAmount => 10;
  bool get hanziBuildEnabled => true;
  bool get socialFeedEnabled => true;
}
