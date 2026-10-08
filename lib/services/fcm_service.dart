import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/app_message.dart';
import 'api_service.dart';
import 'database_service.dart';

/// Bumped whenever a new push is persisted so HomeScreen can reload.
final ValueNotifier<int> messageListRevision = ValueNotifier<int>(0);

const String _channelId = 'notif_app_channel';
const String _channelName = 'Notifications';
const String _channelDescription = 'Incoming push notifications';
const MethodChannel _foregroundNotificationChannel =
    MethodChannel('notif_app/foreground_notification');

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

  await _persistNotification(
    messageId: message.messageId,
    title: title,
    body: body,
    data: jsonEncode(message.data),
  );
}

Future<void> _persistNotification({
  String? messageId,
  required String title,
  required String body,
  required String data,
  DateTime? receivedAt,
}) async {
  final inserted = await DatabaseService.instance.insertMessage(
    AppMessage(
      title: title,
      body: body,
      data: data,
      receivedAt: receivedAt ?? DateTime.now(),
    ),
    messageId: messageId,
  );
  if (inserted) messageListRevision.value++;
}

Future<void> _persistChannelNotification(Map<String, dynamic> args) async {
  final rawData = args['data'];
  final data =
      rawData is Map ? jsonEncode(Map<String, dynamic>.from(rawData)) : '{}';
  final receivedAtMs = int.tryParse(args['receivedAt']?.toString() ?? '');
  await _persistNotification(
    messageId: args['messageId']?.toString(),
    title: args['title']?.toString() ?? 'Notification',
    body: args['body']?.toString() ?? '',
    data: data,
    receivedAt: receivedAtMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(receivedAtMs),
  );
}

class FcmService with WidgetsBindingObserver {
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

    // Banner and Notification Center listing are applied in AppDelegate.
    // Firebase's alert option is ignored on iOS 14+.
    if (!kIsWeb && Platform.isIOS) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    if (!kIsWeb && Platform.isIOS) {
      _foregroundNotificationChannel.setMethodCallHandler((call) async {
        if (call.method != 'onForegroundNotification') return;
        final args = Map<String, dynamic>.from(call.arguments as Map);
        await _persistChannelNotification(args);
      });
      WidgetsBinding.instance.addObserver(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _announceNotificationClient();
        _scheduleDeliveredSync();
      });
    }

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
    try {
      final openedMessage = await messaging
          .getInitialMessage()
          .timeout(const Duration(seconds: 3));
      if (openedMessage != null) {
        await _persistRemoteMessage(openedMessage);
      }
    } catch (e) {
      debugPrint('Initial notification read failed: $e');
    }

    messaging.onTokenRefresh.listen((token) async {
      await syncToken(token);
    });

    _initialized = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _announceNotificationClient();
      _scheduleDeliveredSync();
    }
  }

  Future<void> _announceNotificationClient() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      await _foregroundNotificationChannel
          .invokeMethod<void>('clientReady')
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Notification client ready failed: $e');
    }
  }

  void _scheduleDeliveredSync() {
    syncDeliveredNotifications();
    Future<void>.delayed(
      const Duration(milliseconds: 1200),
      syncDeliveredNotifications,
    );
  }

  /// Copies Notification Center alerts into the message list. Opening the app
  /// without tapping the banner still picks them up. The second pass covers
  /// alerts that land a moment after the app becomes active.
  Future<void> syncDeliveredNotifications() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      final raw = await _foregroundNotificationChannel
          .invokeMethod<List<dynamic>>('getDeliveredNotifications')
          .timeout(const Duration(seconds: 3));
      if (raw != null) {
        for (final item in raw) {
          if (item is Map) {
            await _persistChannelNotification(Map<String, dynamic>.from(item));
          }
        }
      }
    } catch (e) {
      debugPrint('Delivered notification sync failed: $e');
    }
    messageListRevision.value++;
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
          presentBanner: true,
          presentList: true,
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
