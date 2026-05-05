import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'data/services/cache_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/remote_config_service.dart';
import 'firebase_options.dart';
import 'presentation/providers/ai_provider.dart';
import 'presentation/providers/dictionary_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Clean URLs on web (removes the # fragment from routes).
  usePathUrlStrategy();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // FCM background handler must be registered before runApp on mobile only.
  // Web FCM is handled via firebase-messaging-sw.js service worker.
  if (!kIsWeb) {
    NotificationService.registerBackgroundHandler();
  }

  // Hive local cache (works on web via IndexedDB).
  await CacheService.initialize();
  final cache = CacheService();
  await cache.openBoxes();

  // Remote Config — fetches live values, falls back to defaults on failure.
  final remoteConfig = RemoteConfigService();
  await remoteConfig.initialize();

  // Crashlytics error hooks (no-op on web for fatal errors, but non-fatal still works).
  if (!kIsWeb) {
    FlutterError.onError =
        FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  runApp(
    ProviderScope(
      overrides: [
        cacheServiceProvider.overrideWithValue(cache),
        remoteConfigProvider.overrideWithValue(remoteConfig),
      ],
      child: const MandarinAcademyApp(),
    ),
  );
}
