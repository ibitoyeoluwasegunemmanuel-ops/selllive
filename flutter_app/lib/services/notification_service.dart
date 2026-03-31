// lib/services/notification_service.dart
// Push notifications — buyers get alerted when followed sellers go live
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final _fcm = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // Request permission
    await _fcm.requestPermission(
      alert: true, badge: true, sound: true,
    );

    // Local notifications setup
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (details) {
        // Navigate to stream when notification tapped
        if (details.payload != null) {
          // routerKey.currentContext?.push('/stream/${details.payload}');
        }
      },
    );

    // Get and save FCM token
    final token = await _fcm.getToken();
    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });

    // Token refresh
    _fcm.onTokenRefresh.listen((token) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      // TODO: send updated token to backend
    });
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'selllive_live', 'Live Streams',
      channelDescription: 'Notifications when sellers you follow go live',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFFFF5722),
    );

    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data['stream_id'],
    );
  }
}
