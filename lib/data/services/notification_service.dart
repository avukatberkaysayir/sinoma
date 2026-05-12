// Push notifications removed — FCM dependency dropped.
// This stub preserves the call-site API so no other files need changing.
class NotificationService {
  NotificationService._();

  static void registerBackgroundHandler() {}

  static void setNavigationCallback(void Function(String route) callback) {}

  static Future<void> initialize(String uid, dynamic db) async {}
}
