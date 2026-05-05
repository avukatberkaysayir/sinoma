import 'remote_config_service.dart';

// No-op AdService for web — google_mobile_ads does not support Flutter Web.
class AdService {
  AdService({required RemoteConfigService remoteConfig});

  Future<void> initialize() async {}
  void recordVideoCompleted() {}
  bool get shouldShowInterstitial => false;
  Future<void> showInterstitialIfEligible() async {}
  bool get isRewardedAdReady => false;

  Future<void> showRewardedAd({
    required Future<void> Function() onReward,
    required void Function() onDismissed,
  }) async {}

  void dispose() {}
}
