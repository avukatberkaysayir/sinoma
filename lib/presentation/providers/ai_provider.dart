import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_config.dart';
import '../../data/services/ad_service.dart';
import '../../data/services/analytics_service.dart';
import '../../data/services/credit_service.dart';
import '../../data/services/gemini_service.dart';
import '../../data/services/remote_config_service.dart';

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService(apiKey: AppConfig.geminiApiKey);
});

final creditServiceProvider = Provider<CreditService>((ref) {
  return CreditService();
});

final remoteConfigProvider = Provider<RemoteConfigService>(
  (_) => throw UnimplementedError('remoteConfigProvider not initialized'),
);

final adServiceProvider = Provider<AdService>((ref) {
  final service = AdService(remoteConfig: ref.read(remoteConfigProvider));
  service.initialize();
  ref.onDispose(service.dispose);
  return service;
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});
