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
    apiKey: 'AIzaSyAJ8Y0V47fNoKvj1xe9io8GBdCpb3NJ_5E',
    appId: '1:806489100275:web:4577fc71f803c51cc58c86',
    messagingSenderId: '806489100275',
    projectId: 'sinoma',
    authDomain: 'sinoma.firebaseapp.com',
    storageBucket: 'sinoma.firebasestorage.app',
    measurementId: 'G-NWTDF5GE1N',
  );

  // Android/iOS configs will be added when native apps are configured in Firebase Console.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAJ8Y0V47fNoKvj1xe9io8GBdCpb3NJ_5E',
    appId: '1:806489100275:android:0000000000000000c58c86',
    messagingSenderId: '806489100275',
    projectId: 'sinoma',
    storageBucket: 'sinoma.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAJ8Y0V47fNoKvj1xe9io8GBdCpb3NJ_5E',
    appId: '1:806489100275:ios:0000000000000000c58c86',
    messagingSenderId: '806489100275',
    projectId: 'sinoma',
    storageBucket: 'sinoma.firebasestorage.app',
    iosBundleId: 'com.sinoma.app',
  );
}
