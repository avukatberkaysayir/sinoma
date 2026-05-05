import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_config.dart';
import '../../data/services/ad_service.dart';
import '../../data/services/analytics_service.dart';
import '../../data/services/credit_service.dart';
import '../../data/services/gemini_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/remote_config_service.dart';
import 'auth_provider.dart';
import 'user_provider.dart';

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService(apiKey: AppConfig.geminiApiKey);
});

final creditServiceProvider = Provider<CreditService>((ref) {
  return CreditService();
});

final remoteConfigProvider = Provider<RemoteConfigService>(
  (_) => throw UnimplementedError('remoteConfigProvider not initialized'),
);

/// Single AdService instance for the app lifetime.
/// MobileAds.instance.initialize() is called in main.dart before runApp().
/// This provider calls initialize() again (idempotent) to trigger ad preloading.
final adServiceProvider = Provider<AdService>((ref) {
  final service = AdService(remoteConfig: ref.read(remoteConfigProvider));
  service.initialize();
  ref.onDispose(service.dispose);
  return service;
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

/// Initializes FCM + sets Crashlytics/Analytics user identity on sign-in.
/// Read this provider in HomeScreen.build() to activate it.
final fcmInitProvider = Provider<void>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid != null) {
    NotificationService.initialize(uid, FirebaseFirestore.instance);

    // Set identity for Crashlytics and Analytics once per session.
    final user = ref.read(currentUserProvider).valueOrNull;
    ref.read(analyticsServiceProvider).identifyUser(
          uid,
          hskLevel: user?.hskLevel,
          isPremium: user?.isPremium,
        );
  }
});
