import 'package:google_mobile_ads/google_mobile_ads.dart';

// Test IDs — replace with real AdMob IDs before Play Store release.
const _kInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
const _kRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
const _kBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

class AdService {
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  int _videosSinceLastInterstitial = 0;

  // First interstitial after 20 videos, then every 10.
  static const int _firstInterstitialThreshold = 20;
  static const int _repeatInterstitialThreshold = 10;
  bool _firstInterstitialShown = false;

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _preloadInterstitial();
    _preloadRewarded();
  }

  // ---------------------------------------------------------------------------
  // Banner
  // ---------------------------------------------------------------------------

  BannerAd buildBannerAd({required void Function(Ad, LoadAdError) onFailed}) {
    return BannerAd(
      adUnitId: _kBannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(onAdFailedToLoad: onFailed),
    )..load();
  }

  // ---------------------------------------------------------------------------
  // Interstitial
  // ---------------------------------------------------------------------------

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
      return _videosSinceLastInterstitial >= _firstInterstitialThreshold;
    }
    return _videosSinceLastInterstitial >= _repeatInterstitialThreshold;
  }

  Future<void> showInterstitialIfEligible() async {
    if (!shouldShowInterstitial || _interstitialAd == null) return;
    await _interstitialAd!.show();
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        _videosSinceLastInterstitial = 0;
        _firstInterstitialShown = true;
        _preloadInterstitial();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Rewarded
  // ---------------------------------------------------------------------------

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
    required void Function(AdWithoutView, RewardItem) onReward,
    required void Function() onDismissed,
  }) async {
    if (_rewardedAd == null) return;
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        _preloadRewarded();
        onDismissed();
      },
    );
    await _rewardedAd!.show(onUserEarnedReward: onReward);
    _rewardedAd = null;
  }

  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
