import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'persistence_service.dart';

class StepTrackingService {
  static final StepTrackingService _instance = StepTrackingService._internal();
  factory StepTrackingService() => _instance;
  StepTrackingService._internal();

  final _stepsController = StreamController<int>.broadcast();
  Stream<int> get stepsStream => _stepsController.stream;

  int _dailySteps = 0;
  int _totalSteps = 0;
  int _sessionSteps = 0;
  
  int get dailySteps => _dailySteps;
  int get totalSteps => _totalSteps;
  int get sessionSteps => _sessionSteps;

  StreamSubscription<StepCount>? _stepSub;
  bool _initialized = false;
  bool _notificationsEnabled = false;

  // Service instances
  final NotificationService _notificationService = NotificationService();
  final PersistenceService _persistence = PersistenceService();

  // Simple debouncing
  int _lastStepTs = 0;
  final int _minStepMs = 250;

  DateTime _lastDate = DateTime.now();

  /// Initialize sensor permissions
  Future<bool> initialize() async {
    // Prevent reinitialization
    if (_initialized) {
      if (kDebugMode) print("🔄 StepTrackingService already initialized with $_dailySteps steps");
      return true;
    }
    
    // Initialize persistence service
    await _persistence.initialize();
    
    // Request all required permissions
    if (kDebugMode) print("🔐 Requesting permissions...");
    
    // Request sensors permission (required for pedometer)
    final sensorPerm = await Permission.sensors.request();
    if (kDebugMode) print("📱 Sensors permission: $sensorPerm");
    
    // Request activity recognition permission (required for step detection)
    final activityPerm = await Permission.activityRecognition.request();
    if (kDebugMode) print("🏃 Activity recognition permission: $activityPerm");
    
    // Both permissions are required for accurate step tracking
    if (sensorPerm != PermissionStatus.granted) {
      if (kDebugMode) print("❌ Sensor permission not granted: $sensorPerm");
      return false;
    }
    
    if (activityPerm != PermissionStatus.granted) {
      if (kDebugMode) print("❌ Activity recognition permission not granted: $activityPerm");
      return false;
    }

    await _loadPersistedSteps();
    _initialized = true;
    
    if (kDebugMode) print("✅ StepTrackingService initialized with all permissions granted - $_dailySteps daily, $_totalSteps total steps");
    return true;
  }

  /// Start step tracking
  Future<void> startTracking() async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    // Prevent multiple pedometer subscriptions
    if (_stepSub != null) {
      if (kDebugMode) print("🔄 StepTrackingService already tracking - skipping restart");
      return;
    }

    try {
      _stepSub = Pedometer.stepCountStream.listen(
        (event) {
          if (kDebugMode) print("📈 Pedometer event: ${event.steps} steps at ${event.timeStamp}");
          _onStepDetected(event);
        },
        onError: (err) {
          if (kDebugMode) print("❌ Step stream error: $err");
          // Try to restart the stream after a short delay
          Future.delayed(const Duration(seconds: 2), () {
            if (_stepSub == null) { // Only restart if not already restarted
              if (kDebugMode) print("🔄 Attempting to restart step tracking...");
              startTracking();
            }
          });
        },
        cancelOnError: false, // Don't cancel on errors, keep trying
      );

      if (kDebugMode) print("✅ StepTrackingService started tracking from $_dailySteps steps");
    } catch (e) {
      if (kDebugMode) print("❌ Failed to start step tracking: $e");
    }
  }

  /// Handle each pedometer step
  void _onStepDetected(StepCount stepCount) {
    final ts = stepCount.timeStamp.millisecondsSinceEpoch;
    final currentSteps = stepCount.steps;

    // Reject too-fast duplicates (basic debounce)
    if (ts - _lastStepTs < _minStepMs) return;

    // ✅ compute delta BEFORE updating _lastStepTs
    final delta = _lastStepTs == 0 ? _minStepMs : (ts - _lastStepTs);
    _lastStepTs = ts;

    // For pedometer, we typically get total steps, so we need to calculate the difference
    // However, this custom pedometer plugin might work differently, so let's handle both cases
    
    // Simple step counting - just count every valid step from pedometer
    _dailySteps++;
    _totalSteps++;
    _sessionSteps++;
    
    _stepsController.add(_dailySteps);
    _updateNotification();
    _persistSteps();
    
    if (kDebugMode) print("🚶 Step detected: $_dailySteps daily, $_totalSteps total steps (raw: $currentSteps)");
  }


  /// Reset steps at midnight
  void _resetDailySteps() {
    final previousDailySteps = _dailySteps;
    
    // Save yesterday's step history
    if (previousDailySteps > 0) {
      _persistence.saveStepHistory(_lastDate, previousDailySteps);
    }
    
    // Add yesterday's steps to total and reset daily counter
    _totalSteps += previousDailySteps;
    _dailySteps = 0;
    _lastDate = DateTime.now();
    _sessionSteps = 0; // Reset session as well
    
    _stepsController.add(_dailySteps);
    _persistSteps();
    if (kDebugMode) print("🔄 Daily reset: $previousDailySteps steps yesterday, $_totalSteps total steps");
  }

  /// Persist step count using PersistenceService
  Future<void> _persistSteps() async {
    try {
      await _persistence.saveStepData(
        dailySteps: _dailySteps,
        totalSteps: _totalSteps,
        sessionSteps: _sessionSteps,
        lastDate: _lastDate,
        notificationsEnabled: _notificationsEnabled,
      );
    } catch (e) {
      if (kDebugMode) print("❌ Failed to persist steps: $e");
    }
  }

  /// Load persisted step count using PersistenceService
  Future<void> _loadPersistedSteps() async {
    try {
      final stepData = _persistence.loadStepData();
      _dailySteps = stepData['dailySteps'] as int;
      _totalSteps = stepData['totalSteps'] as int;
      _sessionSteps = 0; // Always start fresh session
      _lastDate = stepData['lastDate'] as DateTime;
      _notificationsEnabled = stepData['notificationsEnabled'] as bool;
      
      // Reset if saved date is from a different day
      final now = DateTime.now();
      if (now.day != _lastDate.day || 
          now.month != _lastDate.month || 
          now.year != _lastDate.year) {
        _resetDailySteps();
      }
      
      _stepsController.add(_dailySteps);
      
      if (kDebugMode) print("📖 Loaded persisted steps: $_dailySteps daily, $_totalSteps total");
    } catch (e) {
      if (kDebugMode) print("❌ Failed to load persisted steps: $e");
      // Use defaults
      _dailySteps = 0;
      _totalSteps = 0;
      _sessionSteps = 0;
      _lastDate = DateTime.now();
      _stepsController.add(_dailySteps);
    }
  }

  /// Enable persistent notifications
  Future<void> enableNotifications() async {
    final success = await _notificationService.initialize();
    if (success) {
      _notificationsEnabled = true;
      _updateNotification(); // Show initial notification with current steps
      if (kDebugMode) print("🔔 Step notifications enabled");
    }
  }

  /// Disable persistent notifications
  Future<void> disableNotifications() async {
    _notificationsEnabled = false;
    await _notificationService.hideStepTrackingNotification();
    if (kDebugMode) print("🔕 Step notifications disabled");
  }

  /// Update the persistent notification with current step count
  void _updateNotification() {
    if (_notificationsEnabled) {
      _notificationService.showStepTrackingNotification(_dailySteps);
    }
  }

  /// Check if notifications are enabled
  bool get notificationsEnabled => _notificationsEnabled;

  /// Show milestone notification for achievements
  Future<void> showMilestoneNotification(String title, String message) async {
    await _notificationService.showMilestoneNotification(title, message);
  }

  /// Manually add steps (for Firebase sync or external integration)
  void addSteps(int steps, {String source = 'manual'}) {
    _dailySteps += steps;
    _totalSteps += steps;
    if (source == 'session') {
      _sessionSteps += steps;
    }
    
    _stepsController.add(_dailySteps);
    _persistSteps();
    _updateNotification();
    
    if (kDebugMode) print('➕ Manual steps added: $steps (daily: $_dailySteps, total: $_totalSteps) from $source');
  }

  void stopTracking() {
    _stepSub?.cancel();
    _stepSub = null;
    if (kDebugMode) print("🛑 StepTrackingService stopped");
  }

  /// Get step history for the past N days
  Future<Map<String, int>> getStepHistory({int days = 7}) async {
    return await _persistence.loadStepHistory(maxDays: days);
  }
  
  /// Reset all step data (for testing or data corruption recovery)
  Future<void> resetAllStepData() async {
    _dailySteps = 0;
    _totalSteps = 0;
    _sessionSteps = 0;
    _lastDate = DateTime.now();
    
    await _persistSteps();
    _stepsController.add(_dailySteps);
    _updateNotification();
    
    if (kDebugMode) print("🔄 All step data reset");
  }
  
  void dispose() {
    stopTracking();
    _notificationService.dispose();
    _stepsController.close();
  }
}
