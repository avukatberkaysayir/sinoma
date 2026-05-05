import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Must be top-level — FCM requires this for background isolate entry.
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage _) async {
  // OS tray handles background notifications; no app code needed here.
}

class NotificationService {
  NotificationService._();

  static final _messaging = FirebaseMessaging.instance;
  static void Function(String route)? _onNavigate;

  static final _foregroundController =
      StreamController<RemoteMessage>.broadcast();

  // UI layers can listen to foreground pushes and display in-app banners.
  static Stream<RemoteMessage> get foregroundMessages =>
      _foregroundController.stream;

  // Call once from main() before runApp.
  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
  }

  static void setNavigationCallback(void Function(String route) callback) {
    _onNavigate = callback;
  }

  // Call after sign-in when uid is known.
  static Future<void> initialize(String uid, FirebaseFirestore firestore) async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (granted) {
      await _saveToken(uid, firestore);
      _messaging.onTokenRefresh.listen((token) {
        firestore.collection('users').doc(uid).update({'fcmToken': token});
      });
    }

    FirebaseMessaging.onMessage.listen(_foregroundController.add);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNavigate);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleNavigate(initial);
  }

  static Future<void> _saveToken(String uid, FirebaseFirestore firestore) async {
    final token = await _messaging.getToken();
    if (token != null) {
      await firestore.collection('users').doc(uid).update({'fcmToken': token});
    }
  }

  static void _handleNavigate(RemoteMessage message) {
    final route = message.data['route'] as String?;
    if (route != null) _onNavigate?.call(route);
  }
}
