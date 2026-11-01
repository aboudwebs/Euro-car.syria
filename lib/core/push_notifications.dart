import 'dart:convert';
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  ui.DartPluginRegistrant.ensureInitialized();
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  await PushNotifications.showBackgroundNotification(message);
}

class PushNotifications {
  static const String channelId = 'euro_cars_notifications';
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    channelId,
    'إشعارات EURO CARS',
    description: 'تحديثات الطلبات والحساب والأمان',
    importance: Importance.max,
  );

  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static void Function(Map<String, String>)? _tapHandler;
  static Future<void> Function(String)? _tokenRefreshHandler;
  static Map<String, String>? _pendingTap;
  static bool _initialized = false;

  static void setTapHandler(void Function(Map<String, String>)? handler) {
    _tapHandler = handler;
    final pending = _pendingTap;
    if (handler != null && pending != null) {
      _pendingTap = null;
      handler(pending);
    }
  }

  static void setTokenRefreshHandler(Future<void> Function(String)? handler) {
    _tokenRefreshHandler = handler;
  }

  static void _dispatchTap(Map<String, dynamic> raw) {
    final data = raw.map((key, value) => MapEntry(key, value.toString()));
    final handler = _tapHandler;
    if (handler == null) {
      _pendingTap = data;
    } else {
      handler(data);
    }
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _local.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) _dispatchTap(Map<String, dynamic>.from(decoded));
        } catch (_) {
          // Ignore malformed notification payloads; the app remains usable.
        }
      },
    );

    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _dispatchTap(message.data));
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _tokenRefreshHandler?.call(token);
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _dispatchTap(initial.data);
    _initialized = true;
  }

  /// Displays data-only FCM messages while the app is backgrounded or terminated.
  /// Notification-payload messages are displayed by Android itself and are not duplicated here.
  static Future<void> showBackgroundNotification(RemoteMessage message) async {
    final RemoteNotification? notification = message.notification;
    final String title = notification?.title ?? message.data['title']?.toString() ?? 'EURO CARS';
    final String body = notification?.body ?? message.data['body']?.toString() ?? '';
    if (body.trim().isEmpty) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _local.initialize(settings);
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    await _local.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'إشعارات EURO CARS',
          channelDescription: 'تحديثات الطلبات والحساب والأمان',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString() ?? 'EURO CARS';
    final body = notification?.body ?? message.data['body']?.toString() ?? '';
    if (body.isEmpty) return;
    await _local.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'إشعارات EURO CARS',
          channelDescription: 'تحديثات الطلبات والحساب والأمان',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static Future<String?> currentToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> requestPermissionAndGetToken() async {
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      return await messaging.getToken();
    } catch (_) {
      return null;
    }
  }
}
