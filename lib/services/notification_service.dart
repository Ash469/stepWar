import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  static const int _stepNotificationId = 1001;
  
  /// Initialize the notification service
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      // Request notification permission
      final notificationPermission = await Permission.notification.request();
      if (notificationPermission != PermissionStatus.granted) {
        if (kDebugMode) print('❌ Notification permission not granted');
        return false;
      }

      // Android initialization settings
      const AndroidInitializationSettings androidInitSettings = 
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings iosInitSettings = 
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: false,
          );

      // Combined initialization settings
      const InitializationSettings initSettings = InitializationSettings(
        android: androidInitSettings,
        iOS: iosInitSettings,
      );

      // Initialize the plugin
      final bool? result = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (result == true) {
        _initialized = true;
        if (kDebugMode) print('✅ Notification service initialized');
        return true;
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) print('❌ Failed to initialize notifications: $e');
      return false;
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap if needed
    if (kDebugMode) print('🔔 Notification tapped: ${response.payload}');
  }

  /// Show or update the persistent step tracking notification
  Future<void> showStepTrackingNotification(int steps) async {
    if (!_initialized) {
      final success = await initialize();
      if (!success) return;
    }

    try {
      final calories = _calculateCaloriesFromSteps(steps);
      
      // Android notification details - Making it truly non-dismissible
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'step_tracking_persistent',
        'Step Tracking (Persistent)',
        channelDescription: 'Persistent step counter - cannot be dismissed',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true, // Makes it persistent
        autoCancel: false,
        showWhen: false,
        enableVibration: false,
        playSound: false,
        silent: true,
        icon: '@mipmap/ic_launcher',
        // Make notification completely non-dismissible using category
        category: AndroidNotificationCategory.service,
        visibility: NotificationVisibility.public,
        setAsGroupSummary: false,
        onlyAlertOnce: true,
        actions: <AndroidNotificationAction>[
          // Empty actions list but keeps notification structure for service-like behavior
        ],
        // This ensures it behaves like a foreground service
        channelShowBadge: false,
        ticker: '🚶‍♂️ $steps steps today',
      );

      // iOS notification details
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
        threadIdentifier: 'step_tracking',
      );

      // Combined notification details
      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Show/update the notification
      await _notifications.show(
        _stepNotificationId,
        '🚶‍♂️ $steps steps today',
        '🔥 ${calories.toStringAsFixed(0)} calories burned • Keep moving!',
        notificationDetails,
        payload: 'step_tracking',
      );

      if (kDebugMode) {
        print('🔔 Step notification updated: $steps steps, ${calories.toStringAsFixed(1)} calories');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to show step notification: $e');
    }
  }

  /// Calculate estimated calories burned from step count
  double _calculateCaloriesFromSteps(int steps) {
    const double caloriesPerStep = 0.045; 
    return steps * caloriesPerStep;
  }

  /// Hide the persistent step tracking notification
  Future<void> hideStepTrackingNotification() async {
    try {
      await _notifications.cancel(_stepNotificationId);
      if (kDebugMode) print('🔔 Step tracking notification hidden');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to hide step notification: $e');
    }
  }

  /// Show a milestone notification (achievements, goals reached, etc.)
  Future<void> showMilestoneNotification(String title, String body, {String? payload}) async {
    if (!_initialized) {
      final success = await initialize();
      if (!success) return;
    }

    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'milestone_channel',
        'Milestones & Achievements',
        channelDescription: 'Notifications for goals reached and achievements',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(''),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        threadIdentifier: 'milestones',
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final milestoneId = DateTime.now().millisecondsSinceEpoch % 100000;
      await _notifications.show(
        milestoneId,
        title,
        body,
        notificationDetails,
        payload: payload ?? 'milestone',
      );

      if (kDebugMode) print('🎉 Milestone notification shown: $title');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to show milestone notification: $e');
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      final permission = await Permission.notification.status;
      return permission == PermissionStatus.granted;
    } catch (e) {
      return false;
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    try {
      await _notifications.cancelAll();
      if (kDebugMode) print('🧹 All notifications cleared');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to clear notifications: $e');
    }
  }

  /// Dispose the notification service
  void dispose() {
    // Clean up resources if needed
    if (kDebugMode) print('🧹 Notification service disposed');
  }
}
