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
      'High Importance Notifications', // Title
      description:
          'This channel is used for important notifications.', 
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

  // This is the core function to handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    print("[FCM] Received foreground message: ${notification.title}");

    // 3. Use the local notifications plugin to show the notification
    _localNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel', // Channel ID
          'High Importance Notifications', // Channel name
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
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

  // Sends the token to your backend API
  Future<void> registerTokenWithBackend(String uid, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/notifications/register-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid, 'token': token}),
      );
      if (response.statusCode == 200) {
        print(
            "[NotificationService] Successfully registered FCM token with backend.");
      } else {
        print("Failed to register FCM token: ${response.body}");
      }
    } catch (e) {
      print("Error registering FCM token with backend: $e");
    }
  }

  // A convenient helper to do everything in one call
  Future<void> initializeAndRegister(String uid) async {
    await initialize();
    final token = await getFcmToken();
    if (token != null) {
      await registerTokenWithBackend(uid, token);
    }
  }
}
