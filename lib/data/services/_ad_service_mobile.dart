import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'remote_config_service.dart';

const _kInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
const _kRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

class AdService {
  AdService({required RemoteConfigService remoteConfig})
      : _remoteConfig = remoteConfig;

  final RemoteConfigService _remoteConfig;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  int _videosSinceLastInterstitial = 0;
  bool _firstInterstitialShown = false;

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _preloadInterstitial();
    _preloadRewarded();
  }

  void _preloadInterstitial() {
    InterstitialAd.load(
      adUnitId: _kInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  void recordVideoCompleted() => _videosSinceLastInterstitial++;

  bool get shouldShowInterstitial {
    if (!_firstInterstitialShown) {
      return _videosSinceLastInterstitial >=
          _remoteConfig.interstitialFrequencyFirst;
    }
    return _videosSinceLastInterstitial >=
        _remoteConfig.interstitialFrequencyRepeat;
  }

  Future<void> showInterstitialIfEligible() async {
    if (!shouldShowInterstitial || _interstitialAd == null) return;
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        _videosSinceLastInterstitial = 0;
        _firstInterstitialShown = true;
        _preloadInterstitial();
      },
    );
    await _interstitialAd!.show();
    _interstitialAd = null;
  }

  void _preloadRewarded() {
    RewardedAd.load(
      adUnitId: _kRewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (_) => _rewardedAd = null,
      ),
    );
  }

  bool get isRewardedAdReady => _rewardedAd != null;

  Future<void> showRewardedAd({
    required Future<void> Function() onReward,
    required void Function() onDismissed,
  }) async {
    if (_rewardedAd == null) return;
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        _preloadRewarded();
        onDismissed();
      },
    );
    await _rewardedAd!.show(
      onUserEarnedReward: (_, __) => onReward(),
    );
    _rewardedAd = null;
  }

  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
