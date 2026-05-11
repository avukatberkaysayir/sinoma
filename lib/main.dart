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

const _devEmail    = 'dev@mandarin.local';
const _devPassword = 'dev-local-123';

/// Signs in with the dev account and ensures the Firestore user doc exists.
/// Runs only in kDebugMode — no-op if already signed in.
Future<void> _ensureDevSession() async {
  final auth = FirebaseAuth.instance;
  try {
    if (auth.currentUser == null) {
      try {
        await auth.signInWithEmailAndPassword(
            email: _devEmail, password: _devPassword);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          await auth.createUserWithEmailAndPassword(
              email: _devEmail, password: _devPassword);
        }
      }
    }

    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final firestore = FirebaseFirestore.instance;
    final ref = firestore.collection('users').doc(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'uid': uid,
        'displayName': 'Dev User',
        'email': _devEmail,
        'photoUrl': '',
        'hskLevel': 3,
        'isPremium': true,
        'aiCredits': 999,
        'followers': [],
        'following': [],
        'learnedWords': [],
        'stats': {
          'totalScore': 0,
          'videosWatched': 0,
          'questionsAnswered': 0,
          'currentStreak': 0,
        },
        'createdAt': Timestamp.now(),
      });
    }
  } catch (_) {
    // Emulator not reachable — silently skip, app will show onboarding.
  }
}

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

    // Auto-sign-in with the dev account so every rebuild goes straight to /home.
    await _ensureDevSession();
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
      child: const SinomaApp(),
    ),
  );
}
