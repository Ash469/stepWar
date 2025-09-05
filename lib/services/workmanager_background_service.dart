import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

/// Pure WorkManager-based background step service
/// This approach is the most reliable for background tasks on Android
class BackgroundStepService {
  static const String _backgroundStepSyncTask = 'step_sync_background';
  static const String _backgroundMaintenanceTask = 'background_maintenance';
  
  static final BackgroundStepService _instance = BackgroundStepService._internal();
  factory BackgroundStepService() => _instance;
  BackgroundStepService._internal();

  bool _isInitialized = false;
  StreamController<Map<String, dynamic>?>? _stepUpdateController;
  
  /// Initialize background step counting
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Initialize WorkManager
      await _initializeWorkManager();
      
      // Initialize step update stream
      _stepUpdateController = StreamController<Map<String, dynamic>?>.broadcast();
      
      _isInitialized = true;
      if (kDebugMode) print('✅ WorkManager background step service initialized');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Background step service initialization failed: $e');
      return false;
    }
  }

  /// Initialize WorkManager for periodic tasks
  Future<void> _initializeWorkManager() async {
    await Workmanager().initialize(
      _workManagerCallbackDispatcher,
      isInDebugMode: kDebugMode,
    );

    if (kDebugMode) print('✅ WorkManager initialized');
  }

  /// Start background step counting
  Future<bool> startBackgroundCounting() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    try {
      // Request necessary permissions
      final permissions = await _requestBackgroundPermissions();
      if (!permissions) {
        if (kDebugMode) print('❌ Background permissions not granted');
        return false;
      }

      // Register periodic tasks
      await Workmanager().registerPeriodicTask(
        _backgroundStepSyncTask,
        _backgroundStepSyncTask,
        frequency: const Duration(hours: 1),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
        ),
      );

      await Workmanager().registerPeriodicTask(
        _backgroundMaintenanceTask,
        _backgroundMaintenanceTask,
        frequency: const Duration(hours: 6),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
        ),
      );

      // Save background service state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', true);
      await prefs.setString('background_service_started', DateTime.now().toIso8601String());

      if (kDebugMode) print('🚀 Background step counting started with WorkManager');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Failed to start background counting: $e');
      return false;
    }
  }

  /// Stop background step counting
  Future<void> stopBackgroundCounting() async {
    try {
      // Cancel WorkManager tasks
      await Workmanager().cancelByUniqueName(_backgroundStepSyncTask);
      await Workmanager().cancelByUniqueName(_backgroundMaintenanceTask);

      // Save background service state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_enabled', false);
      await prefs.setString('background_service_stopped', DateTime.now().toIso8601String());

      if (kDebugMode) print('🛑 Background step service stopped');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to stop background counting: $e');
    }
  }

  /// Request background processing permissions
  Future<bool> _requestBackgroundPermissions() async {
    final permissions = [
      Permission.activityRecognition,
      Permission.sensors,
    ];

    final statuses = await permissions.request();
    final allGranted = statuses.values.every(
      (status) => status == PermissionStatus.granted || status == PermissionStatus.permanentlyDenied
    );

    if (!allGranted && kDebugMode) {
      print('❌ Background permissions not fully granted:');
      statuses.forEach((permission, status) {
        print('  $permission: $status');
      });
    }

    // Return true even if not all granted - we'll work with what we have
    return true;
  }

  /// Check if background service is running
  Future<bool> isBackgroundServiceRunning() async {
    if (!_isInitialized) return false;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('background_service_enabled') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get background step count
  Future<int> getBackgroundSteps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('background_daily_steps') ?? 0;
  }

  /// Sync background steps with main counter
  Future<void> syncWithMainCounter() async {
    await _syncWithMainCounter();
  }

  /// Listen to background step updates (simplified)
  Stream<Map<String, dynamic>?> get backgroundStepStream {
    return _stepUpdateController?.stream ?? Stream.empty();
  }

  /// Emit step update to listeners
  void _emitStepUpdate(int steps) {
    _stepUpdateController?.add({
      'steps': steps,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Dispose resources
  void dispose() {
    _stepUpdateController?.close();
    if (kDebugMode) print('🧹 Background step service dispose called');
  }
}

/// WorkManager callback dispatcher
@pragma('vm:entry-point')
void _workManagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (kDebugMode) print('🔄 Background task started: $task');
    
    try {
      switch (task) {
        case BackgroundStepService._backgroundStepSyncTask:
          await _performBackgroundStepSync();
          break;
        case BackgroundStepService._backgroundMaintenanceTask:
          await _performBackgroundMaintenance();
          break;
        default:
          if (kDebugMode) print('⚠️ Unknown background task: $task');
      }
      
      if (kDebugMode) print('✅ Background task completed: $task');
      return Future.value(true);
    } catch (e) {
      if (kDebugMode) print('❌ Background task failed: $task, error: $e');
      return Future.value(false);
    }
  });
}

/// Perform background step sync
Future<void> _performBackgroundStepSync() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final mainSteps = prefs.getInt('daily_steps') ?? 0;
    final backgroundSteps = prefs.getInt('background_daily_steps') ?? 0;
    
    // Keep background steps in sync with main counter
    if (mainSteps > backgroundSteps) {
      await prefs.setInt('background_daily_steps', mainSteps);
      if (kDebugMode) print('🔄 Background steps synced to main counter: $mainSteps');
    }
    
    // Update sync timestamp
    await prefs.setString('last_background_sync', DateTime.now().toIso8601String());
    
    if (kDebugMode) print('✅ Background sync completed');
  } catch (e) {
    if (kDebugMode) print('❌ Background sync failed: $e');
  }
}

/// Perform background maintenance tasks
Future<void> _performBackgroundMaintenance() async {
  try {
    await _checkDailyReset();
    await _cleanupOldData();
    
    if (kDebugMode) print('✅ Background maintenance completed');
  } catch (e) {
    if (kDebugMode) print('❌ Background maintenance failed: $e');
  }
}

/// Sync with main counter
Future<void> _syncWithMainCounter() async {
  await _performBackgroundStepSync();
}

/// Check for daily reset
Future<void> _checkDailyReset() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastResetStr = prefs.getString('background_last_reset');
    final now = DateTime.now();
    
    DateTime? lastReset;
    if (lastResetStr != null) {
      lastReset = DateTime.tryParse(lastResetStr);
    }
    
    // Check if we need to reset (new day)
    if (lastReset == null || 
        now.day != lastReset.day || 
        now.month != lastReset.month || 
        now.year != lastReset.year) {
      
      // Reset daily steps
      await prefs.setInt('background_daily_steps', 0);
      await prefs.setString('background_last_reset', now.toIso8601String());
      
      if (kDebugMode) print('🔄 Background daily reset performed');
    }
  } catch (e) {
    if (kDebugMode) print('❌ Daily reset check failed: $e');
  }
}

/// Clean up old data and preferences
Future<void> _cleanupOldData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Remove old timestamps older than 7 days
    final keysToCheck = [
      'background_last_update',
      'last_background_sync',
    ];
    
    final now = DateTime.now();
    for (final key in keysToCheck) {
      final timestampStr = prefs.getString(key);
      if (timestampStr != null) {
        final timestamp = DateTime.tryParse(timestampStr);
        if (timestamp != null && now.difference(timestamp).inDays > 7) {
          await prefs.remove(key);
          if (kDebugMode) print('🧹 Cleaned up old data: $key');
        }
      }
    }
  } catch (e) {
    if (kDebugMode) print('❌ Cleanup failed: $e');
  }
}
