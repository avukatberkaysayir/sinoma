import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  usePathUrlStrategy();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Connect to Firebase Emulators in debug builds.
  // In release builds (production), this block is skipped.
  if (kDebugMode) {
    const emulatorHost = 'localhost';
    try {
      await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9199);
      FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 9299);
    } catch (_) {
      // Emulator not running — fall through to production Firebase.
    }
  }

  if (!kIsWeb) {
    NotificationService.registerBackgroundHandler();
  }

  await CacheService.initialize();
  final cache = CacheService();
  await cache.openBoxes();

  final remoteConfig = RemoteConfigService();
  await remoteConfig.initialize();

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
