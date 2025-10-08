import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final String _baseUrl = "https://stepwars-backend.onrender.com";

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
        AndroidInitializationSettings('@drawable/ic_notification');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotificationsPlugin.initialize(settings);
  }

  void showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
        ),
      ),
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print("[FCM] Received foreground message: ${message.notification?.title}");
    showLocalNotification(message); // Use the new shared method
  }

  Future<void> initialize() async {
    await _initializeLocalNotifications();
    await _firebaseMessaging.requestPermission();
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      print("[FCM] Token refreshed: $newToken");
    });
  }

  Future<String?> getFcmToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      print("[FCM] Fetched token: $token");
      return token;
    } catch (e) {
      print("Error getting FCM token: $e");
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
        print(
            "[NotificationService] Successfully registered FCM token with backend.");
        return true;
      } else {
        print("Failed to register FCM token: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error registering FCM token with backend: $e");
      return false;
    }
  }

  Future<void> unregisterTokenFromBackend(String uid, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/notifications/unregister-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid, 'token': token}),
      );
      if (response.statusCode == 200) {
        print(
            "[NotificationService] Successfully unregistered FCM token from backend.");
      } else {
        print("Failed to unregister FCM token: ${response.body}");
      }
    } catch (e) {
      print("Error unregistering FCM token with backend: $e");
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
