import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../const/string.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  String get _baseUrl => getBackendUrl();

  Completer<void>? _initCompleter;

  Future<void> initialize() {
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();

    _initializeLocalNotifications().then((_) async {

      // Attach foreground listener
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessage.listen(_handleBackgroundMessage);

      _initCompleter!.complete();
    });

    return _initCompleter!.future;
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings(
            '@drawable/ic_notification'); // Small icon

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotificationsPlugin.initialize(settings);
  }

  Future<void> showLocalNotification(RemoteMessage message) async {
    await initialize();

    final notification = message.notification;
    if (notification == null) return;

    const Color notificationColor = Color(0xFFFFC107);
    AndroidNotificationDetails androidDetails;

    final String? imageUrl = notification.android?.imageUrl;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(imageUrl));
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/notification_image.png';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        final largeIcon = FilePathAndroidBitmap(filePath);

        androidDetails = AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.max,
          priority: Priority.high,
          largeIcon: largeIcon,
          styleInformation: BigTextStyleInformation(
            notification.body ?? '',
            contentTitle: notification.title,
          ),
          color: notificationColor,
          groupKey: 'com.stepwars.battle_notifications',
        );
      } catch (e) {
        androidDetails = const AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.max,
          priority: Priority.high,
          color: notificationColor,
          groupKey: 'com.stepwars.battle_notifications',
        );
      }
    } else {
      androidDetails = const AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        importance: Importance.max,
        priority: Priority.high,
        color: notificationColor,
        groupKey: 'com.stepwars.battle_notifications',
      );
    }

    final notificationDetails = NotificationDetails(android: androidDetails);
    await _localNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      notificationDetails,
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print("[FCM] Foreground message: ${message.notification?.title}");
    showLocalNotification(message);
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    print("[FCM] Foreground message: ${message.notification?.title}");
    showLocalNotification(message);
  }

  Future<String?> getFcmToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      print("[FCM] Token: $token");
      return token;
    } catch (e) {
      print("Error fetching FCM token: $e");
      return null;
    }
  }

  Future<bool> registerTokenWithBackend(String uid, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/notifications/register-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid, 'token': token}),
      );
      if (response.statusCode == 200) {
        print("[NotificationService] Token registered successfully.");
        return true;
      } else {
        print("Failed to register token: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error registering token: $e");
      return false;
    }
  }
  //not used currently but may be used in future
  Future<void> unregisterTokenFromBackend(String uid, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/notifications/unregister-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid, 'token': token}),
      );
      if (response.statusCode == 200) {
        print("[NotificationService] Token unregistered successfully.");
      } else {
        print("Failed to unregister token: ${response.body}");
      }
    } catch (e) {
      print("Error unregistering token: $e");
    }
  }

  Future<void> initializeAndRegister(String uid) async {
    await initialize();
    final token = await getFcmToken();
    if (token != null) {
      await registerTokenWithBackend(uid, token);
    }
  }
}
