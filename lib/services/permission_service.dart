import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/permission_model.dart';

class PermissionService {
  static const MethodChannel _autoStartChannel =
      MethodChannel('auto_start_channel');

  static const String _autostartEnabledKey = 'autostart_permission_enabled';
  static List<AppPermission> getAllPermissions() {
    return [
      AppPermission(
        id: 'activity_recognition',
        title: 'Step Counter',
        description: 'Required to count your steps and track your activity',
        icon: Icons.directions_walk,
        iconColor: const Color(0xFF4CAF50),
        isRequired: true,
      ),
      AppPermission(
        id: 'battery_optimization',
        title: 'Battery Optimization',
        description: 'Keeps step counting running in the background',
        icon: Icons.battery_charging_full,
        iconColor: const Color(0xFFFFC107),
        isRequired: true,
      ),
      AppPermission(
        id: 'notification',
        title: 'Notifications',
        description: 'Shows step count and battle updates',
        icon: Icons.notifications_active,
        iconColor: const Color(0xFF2196F3),
        isRequired: true,
      ),
      AppPermission(
        id: 'autostart',
        title: 'Auto-Start on Boot',
        description:
            'Enable from settings to auto-start step counting after restart',
        icon: Icons.restart_alt,
        iconColor: const Color(0xFF9C27B0),
        isRequired: true,
      ),
    ];
  }

  static Future<List<AppPermission>> checkAllPermissions() async {
    final permissions = getAllPermissions();

    for (var permission in permissions) {
      switch (permission.id) {
        case 'activity_recognition':
          final status = await Permission.activityRecognition.status;
          permission.isGranted = status.isGranted;
          break;

        case 'battery_optimization':
          final isIgnoring =
              await FlutterForegroundTask.isIgnoringBatteryOptimizations;
          permission.isGranted = isIgnoring;
          break;

        case 'notification':
          final notificationPermission =
              await FlutterForegroundTask.checkNotificationPermission();
          permission.isGranted =
              notificationPermission == NotificationPermission.granted;
          break;

        case 'autostart':
          final prefs = await SharedPreferences.getInstance();
          permission.isGranted = prefs.getBool(_autostartEnabledKey) ?? false;
          break;
      }
    }

    return permissions;
  }

  static Future<bool> requestPermission(String permissionId) async {
    switch (permissionId) {
      case 'activity_recognition':
        final status = await Permission.activityRecognition.request();
        return status.isGranted;

      case 'battery_optimization':
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
        final isIgnoring =
            await FlutterForegroundTask.isIgnoringBatteryOptimizations;
        return isIgnoring;

      case 'notification':
        await FlutterForegroundTask.requestNotificationPermission();
        final notificationPermission =
            await FlutterForegroundTask.checkNotificationPermission();
        return notificationPermission == NotificationPermission.granted;

      case 'autostart':
        try {
          await _autoStartChannel.invokeMethod('openAutoStart');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_autostartEnabledKey, true);
          return true;
        } catch (e) {
          print('Error opening auto-start settings: $e');
          return false;
        }

      default:
        return false;
    }
  }

  /// Open app settings if a permission is permanently denied
  static Future<void> openSettings(String permissionId) async {
    switch (permissionId) {
      case 'activity_recognition':
        await openAppSettings();
        break;

      case 'battery_optimization':
        await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
        break;

      case 'notification':
        await FlutterForegroundTask.requestNotificationPermission();
        break;

      case 'autostart':
        try {
          await _autoStartChannel.invokeMethod('openAutoStart');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_autostartEnabledKey, true);
        } catch (e) {
          print('Error opening auto-start settings: $e');
        }
        break;
    }
  }

  static Future<bool> areAllPermissionsGranted() async {
    final permissions = await checkAllPermissions();
    return permissions.every((p) => p.isGranted || !p.isRequired);
  }
}
