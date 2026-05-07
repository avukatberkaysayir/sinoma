// Firebase demo project config — works with Firebase Emulator Suite.
// For production deployment, replace with real values from:
//   flutterfire configure --project=YOUR_REAL_PROJECT_ID

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:web:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-mandarin-academy',
    authDomain: 'demo-mandarin-academy.firebaseapp.com',
    storageBucket: 'demo-mandarin-academy.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:android:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-mandarin-academy',
    storageBucket: 'demo-mandarin-academy.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:ios:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-mandarin-academy',
    storageBucket: 'demo-mandarin-academy.appspot.com',
    iosBundleId: 'com.mandarinacademy.app',
  );
}
