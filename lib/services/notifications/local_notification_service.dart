import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Singleton service for showing local notifications and handling taps.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Callback invoked when a notification is tapped (local or FCM).
  /// Receives the payload map.
  void Function(Map<String, dynamic> payload)? onNotificationTapped;

  /// Stores FCM payload from getInitialMessage when app was terminated.
  /// Consumed once the router + callback is ready.
  Map<String, dynamic>? pendingFcmPayload;

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onTap,
    );

    // Request permission on Android 13+.
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  void _onTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      onNotificationTapped?.call(data);
    } catch (_) {}
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'tanod_notifications',
      'Tanod Notifications',
      channelDescription: 'Notifications from Tanod',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload != null ? jsonEncode(payload) : null,
    );
  }

  /// Navigate from an FCM data payload (background tap / initial message).
  void handleFcmNavigation(Map<String, dynamic> data) {
    onNotificationTapped?.call(data);
  }
}
