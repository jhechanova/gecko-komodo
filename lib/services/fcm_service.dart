import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/app_message.dart';
import 'api_service.dart';
import 'database_service.dart';

/// Bumped whenever a new push is persisted so HomeScreen can reload.
final ValueNotifier<int> messageListRevision = ValueNotifier<int>(0);

const String _channelId = 'notif_app_channel';
const String _channelName = 'Notifications';
const String _channelDescription = 'Incoming push notifications';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await _persistRemoteMessage(message);
}

Future<void> _persistRemoteMessage(RemoteMessage message) async {
  final notification = message.notification;
  final title = notification?.title ??
      message.data['title']?.toString() ??
      'Notification';
  final body =
      notification?.body ?? message.data['body']?.toString() ?? '';

  await DatabaseService.instance.insertMessage(
    AppMessage(
      title: title,
      body: body,
      data: jsonEncode(message.data),
      receivedAt: DateTime.now(),
    ),
  );
  messageListRevision.value++;
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  FirebaseMessaging get messaging {
    final existing = _messaging;
    if (existing != null) return existing;
    return _messaging = FirebaseMessaging.instance;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    await Firebase.initializeApp();
    _messaging = FirebaseMessaging.instance;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
      ),
    );

    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );
    }

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // iOS: show system banners while app is in foreground.
    if (!kIsWeb && Platform.isIOS) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

    messaging.onTokenRefresh.listen((token) async {
      await syncToken(token);
    });

    _initialized = true;
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    await _persistRemoteMessage(message);

    // Android always needs a local notification in foreground.
    // iOS uses setForegroundNotificationPresentationOptions for notification
    // payloads; still show a local notification for data-only messages.
    final isAndroid = !kIsWeb && Platform.isAndroid;
    final isDataOnlyIos =
        !kIsWeb && Platform.isIOS && message.notification == null;
    if (isAndroid || isDataOnlyIos) {
      await _showLocalNotification(message);
    }
  }

  Future<void> _onMessageOpened(RemoteMessage message) async {
    await _persistRemoteMessage(message);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ??
        message.data['title']?.toString() ??
        'Notification';
    final body =
        notification?.body ?? message.data['body']?.toString() ?? '';

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  Future<String?> getToken() => messaging.getToken();

  /// Registers the device token with the backend when a user is logged in.
  Future<void> getAndSyncToken() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return;
    await syncToken(token);
  }

  Future<void> syncToken(String token) async {
    final db = DatabaseService.instance;
    final user = await db.getUser();
    final baseUrl = await db.getBaseUrl();
    if (user == null || baseUrl == null || baseUrl.isEmpty) return;

    final deviceId = await db.getOrCreateDeviceId();

    await ApiService.instance.registerFcmToken(
      baseUrl: baseUrl,
      userId: user.id,
      fcmToken: token,
      deviceId: deviceId,
    );

    await db.saveUser(user.copyWith(fcmToken: token));
  }
}
