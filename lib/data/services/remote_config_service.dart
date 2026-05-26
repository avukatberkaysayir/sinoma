import 'package:supabase_flutter/supabase_flutter.dart';

// Reads feature flags and tuning values from the `app_config` Supabase table.
// Falls back to hardcoded defaults if the table is unreachable (offline / first launch).
class RemoteConfigService {
  static final _db = Supabase.instance.client;

  Map<String, dynamic> _config = {};
  bool _loaded = false;

  Future<void> initialize() async {
    try {
      final rows = await _db
          .from('app_config')
          .select('key, value')
          .timeout(const Duration(seconds: 5));
      _config = {
        for (final row in (rows as List<dynamic>))
          row['key'] as String: row['value'],
      };
      _loaded = true;
    } catch (_) {
      _loaded = false;
    }
  }

  T _get<T>(String key, T fallback) {
    if (!_loaded) return fallback;
    final v = _config[key];
    if (v == null) return fallback;
    if (v is T) return v;
    if (T == int && v is num) return v.toInt() as T;
    if (T == double && v is num) return v.toDouble() as T;
    if (T == bool && v is bool) return v as T;
    return fallback;
  }

  int  get interstitialFrequencyFirst  => _get('interstitial_frequency_first',  20);
  int  get interstitialFrequencyRepeat => _get('interstitial_frequency_repeat', 10);
  int  get aiCreditsDailyFree          => _get('ai_credits_daily_free',          5);
  int  get maxAiCredits                => _get('max_ai_credits',                50);
  int  get minHskVideosRequired        => _get('min_hsk_videos_required',       20);
  int  get minLearnedWordsRequired     => _get('min_learned_words_required',    50);
  bool get placementTestEnabled        => _get('placement_test_enabled',      true);
  int  get rewardedAdCreditsAmount     => _get('rewarded_ad_credits_amount',    10);
  bool get hanziBuildEnabled           => _get('hanzi_build_enabled',          true);
  bool get socialFeedEnabled           => _get('social_feed_enabled',          true);
}
