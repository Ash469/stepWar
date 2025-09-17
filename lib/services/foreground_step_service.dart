import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Foreground service that creates a truly non-removable notification
/// This runs in a separate isolate and keeps the notification persistent
class ForegroundStepService {
  static final ForegroundStepService _instance = ForegroundStepService._internal();
  factory ForegroundStepService() => _instance;
  ForegroundStepService._internal();

  bool _isRunning = false;

  /// Initialize and start the foreground service
  Future<bool> startForegroundService() async {
    if (_isRunning) {
      if (kDebugMode) print('🔄 Foreground service already running');
      return true;
    }

    try {
      // Initialize foreground task
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'stepwars_step_counter',
          channelName: 'StepWars Step Counter',
          channelDescription: 'Persistent step counter notification - cannot be dismissed',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false, // iOS doesn't support persistent notifications
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(5000), // Update every 5 seconds
          autoRunOnBoot: true,
          allowWakeLock: true,
          allowWifiLock: false,
        ),
      );

      // Start the foreground service
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: '🚶‍♂️ StepWars Active',
        notificationText: 'Tracking your steps...',
        callback: startForegroundTaskCallback,
      );

      _isRunning = true;
      if (kDebugMode) print('✅ Foreground service started');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Error starting foreground service: $e');
      return false;
    }
  }

  /// Stop the foreground service
  Future<void> stopForegroundService() async {
    if (!_isRunning) return;

    try {
      await FlutterForegroundTask.stopService();
      _isRunning = false;
      if (kDebugMode) print('🛑 Foreground service stopped');
    } catch (e) {
      if (kDebugMode) print('❌ Error stopping foreground service: $e');
    }
  }

  /// Update the notification with new step count
  Future<void> updateNotification(int steps) async {
    if (!_isRunning) return;

    try {
      final calories = (steps * 0.045).toStringAsFixed(0);
      
      await FlutterForegroundTask.updateService(
        notificationTitle: '🚶‍♂️ $steps steps today',
        notificationText: '🔥 $calories calories burned • Keep moving!',
      );
      
      if (kDebugMode) print('🔔 Notification updated: $steps steps');
    } catch (e) {
      if (kDebugMode) print('❌ Error updating notification: $e');
    }
  }

  /// Check if foreground service is running
  bool get isRunning => _isRunning;

  /// Restart service if needed
  Future<void> restartIfNeeded() async {
    final isServiceRunning = await FlutterForegroundTask.isRunningService;
    if (!isServiceRunning && !_isRunning) {
      await startForegroundService();
    }
  }

  /// Dispose resources
  void dispose() {
    stopForegroundService();
    if (kDebugMode) print('🗑️ Foreground step service disposed');
  }
}

/// Foreground task callback that runs in a separate isolate
@pragma('vm:entry-point')
void startForegroundTaskCallback() {
  // This runs in a separate isolate
  FlutterForegroundTask.setTaskHandler(StepForegroundTaskHandler());
}

/// Task handler that manages the foreground service
class StepForegroundTaskHandler extends TaskHandler {
  int _stepCount = 0;
  Timer? _updateTimer;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    if (kDebugMode) print('🚀 Foreground task started at $timestamp');

    // Start periodic updates
    _updateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _updateStepNotification();
    });

    _updateStepNotification();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // This method is called every interval (5 seconds)
    _updateStepNotification();
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    if (kDebugMode) print('🛑 Foreground task destroyed at $timestamp');
    _updateTimer?.cancel();
  }

  /// Update the notification with current step count
  void _updateStepNotification() {
    try {
      // In a real implementation, you would get steps from a shared source
      // For now, we'll simulate step counting
      final calories = (_stepCount * 0.045).toStringAsFixed(0);
      
      FlutterForegroundTask.updateService(
        notificationTitle: '🚶‍♂️ $_stepCount steps today',
        notificationText: '🔥 $calories calories • StepWars tracking...',
      );
      
    } catch (e) {
      if (kDebugMode) print('❌ Error in foreground task: $e');
    }
  }

  /// Update step count from external source
  void updateStepCount(int steps) {
    _stepCount = steps;
    _updateStepNotification();
  }
}

/// Utility class to manage foreground task permissions
class ForegroundTaskPermissions {
  /// Check if foreground task permission is granted
  static Future<bool> isPermissionGranted() async {
    return await FlutterForegroundTask.isIgnoringBatteryOptimizations;
  }

  /// Request foreground task permission
  static Future<bool> requestPermission() async {
    // Request to ignore battery optimization
    final batteryOptimization = await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    
    if (kDebugMode) {
      print('🔋 Battery optimization ignored: $batteryOptimization');
    }

    return batteryOptimization;
  }

  /// Open battery optimization settings
  static Future<void> openBatteryOptimizationSettings() async {
    await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
  }
}
