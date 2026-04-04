import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tanodmobile/app/app.dart';
import 'package:tanodmobile/services/notifications/local_notification_service.dart';
import 'package:tanodmobile/services/storage/hive_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp();
  await HiveService.initialize();
  await LocalNotificationService.instance.init();

  // Handle FCM messages while app is in the foreground.
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    LocalNotificationService.instance.show(
      id: message.hashCode,
      title: notification.title ?? '',
      body: notification.body ?? '',
      payload: message.data,
    );
  });

  // Handle notification tap when app is opened from background.
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    LocalNotificationService.instance.handleFcmNavigation(message.data);
  });

  // Handle notification tap when app was terminated.
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    LocalNotificationService.instance.pendingFcmPayload = initialMessage.data;
  }

  runApp(const TanodMobileApp());
}
