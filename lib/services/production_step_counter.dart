import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'step_analytics_service.dart';
import 'step_detection_algorithm.dart';
import 'step_counter_types.dart';
import 'workmanager_background_service.dart';

/// Production-grade step counter with multi-layered filtering
/// Implements the layered filtering approach for accurate step detection
class ProductionStepCounter {
  static final ProductionStepCounter _instance = ProductionStepCounter._internal();
  factory ProductionStepCounter() => _instance;
  ProductionStepCounter._internal();

  // Stream controllers
  final _stepsController = StreamController<int>.broadcast();
  final _stepEventController = StreamController<StepEvent>.broadcast();
  
  Stream<int> get stepsStream => _stepsController.stream;
  Stream<StepEvent> get stepEventStream => _stepEventController.stream;

  // Core state
  int _dailySteps = 0;
  int _totalSteps = 0; // Cumulative steps across all days
  int _sessionSteps = 0;
  int get dailySteps => _dailySteps;
  int get totalSteps => _totalSteps;
  int get sessionSteps => _sessionSteps;
  bool _initialized = false;
  bool _isTracking = false;

  // Activity Recognition
  ActivityState _activityState = ActivityState.unknown;
  int _lastActivityUpdate = 0;
  StreamSubscription<Activity>? _activitySub;

  // Simple step tracking
  int _lastStepTimestamp = 0;

  // Basic timing validation
  final int _minStepInterval = 150; // Minimum 150ms between steps (400 spm max)

  // Anomaly filters
  final int _maxBurstSteps = 4; // Max steps in 1 second
  final int _burstTimeWindow = 1000; // 1 second
  final int _vehicleCooldown = 10000; // 10 seconds
  int _lastVehicleDetection = 0;
  final List<int> _recentStepTimestamps = [];

  // Sensor streams
  StreamSubscription<UserAccelerometerEvent>? _accelerometerSub;
  StreamSubscription<StepCount>? _pedometerSub;

  // Analytics
  final StepAnalyticsService _analytics = StepAnalyticsService();

  // Advanced step detection (fallback)
  final StepDetectionAlgorithm _stepDetector = StepDetectionAlgorithm();
  
  // Background step service
  final BackgroundStepService _backgroundService = BackgroundStepService();
  StreamSubscription<Map<String, dynamic>?>? _backgroundStepSub;

  // Date tracking
  DateTime _lastDate = DateTime.now();
  
  // Pedometer baseline for daily counting
  int _pedometerBaseline = 0;
  int _lastPedometerSteps = 0;

  /// Initialize the step counter with all required permissions and services
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      // Request permissions
      final permissions = await _requestPermissions();
      if (!permissions) {
        _analytics.logError('permissions_denied', 'Required permissions not granted');
        return false;
      }

      // Load persisted data
      await _loadPersistedData();

      // Initialize activity recognition
      await _initializeActivityRecognition();

      // Initialize sensor streams
      await _initializeSensorStreams();
      
      // Initialize background step service
      await _initializeBackgroundService();

      _initialized = true;
      _analytics.logEvent('step_counter_initialized');
      return true;
    } catch (e) {
      _analytics.logError('initialization_failed', e.toString());
      if (kDebugMode) print('❌ StepCounter initialization failed: $e');
      return false;
    }
  }

  /// Request all required permissions
  Future<bool> _requestPermissions() async {
    final permissions = [
      Permission.activityRecognition,
      Permission.sensors,
    ];

    // First check current status
    Map<Permission, PermissionStatus> currentStatuses = await permissions.request();
    
    // Check if all permissions are already granted
    bool allGranted = currentStatuses.values.every(
      (status) => status == PermissionStatus.granted
    );
    
    if (kDebugMode) {
      print('🔍 Permission check results:');
      currentStatuses.forEach((permission, status) {
        print('  $permission: $status');
      });
      print('  All granted: $allGranted');
    }
    
    // If not all granted, check if any are permanently denied
    if (!allGranted) {
      bool hasPermanentlyDenied = currentStatuses.values.any(
        (status) => status == PermissionStatus.permanentlyDenied
      );
      
      if (hasPermanentlyDenied) {
        if (kDebugMode) {
          print('⚠️ Some permissions permanently denied - user needs to enable in settings');
        }
        // Still return true if at least one critical permission (sensors) is available
        return currentStatuses[Permission.sensors] == PermissionStatus.granted;
      }
      
      // Try requesting again for denied permissions
      final retryStatuses = <Permission, PermissionStatus>{};
      for (final permission in permissions) {
        if (currentStatuses[permission] != PermissionStatus.granted) {
          retryStatuses[permission] = await permission.request();
        } else {
          retryStatuses[permission] = currentStatuses[permission]!;
        }
      }
      
      allGranted = retryStatuses.values.every(
        (status) => status == PermissionStatus.granted
      );
      
      if (kDebugMode) {
        print('🔄 After retry:');
        retryStatuses.forEach((permission, status) {
          print('  $permission: $status');
        });
        print('  All granted: $allGranted');
      }
    }
    
    // For step counting, sensors permission is most critical
    // Activity recognition helps but isn't strictly required
    final sensorsGranted = currentStatuses[Permission.sensors] == PermissionStatus.granted;
    if (sensorsGranted && !allGranted) {
      if (kDebugMode) {
        print('✅ Sensors permission granted - can proceed with limited functionality');
      }
      return true; // Can work with just sensors
    }

    return allGranted;
  }
  
  /// Initialize background step service
  Future<void> _initializeBackgroundService() async {
    try {
      final success = await _backgroundService.initialize();
      if (success) {
        // Listen to background step updates
        _backgroundStepSub = _backgroundService.backgroundStepStream.listen((update) {
          if (update == null) return;
          
          final backgroundSteps = update['steps'] as int? ?? 0;
          if (backgroundSteps > _dailySteps) {
            final difference = backgroundSteps - _dailySteps;
            if (kDebugMode) print('🔄 Received $difference steps from background service');
            
            _dailySteps = backgroundSteps;
            _emitStepUpdate();
          }
        });
        
        // Sync with background steps on initialization
        await _syncWithBackgroundService();
        
        if (kDebugMode) print('✅ Background step service integrated');
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Background service integration failed: $e');
      // Continue without background service
    }
  }
  
  /// Sync with background step service
  Future<void> _syncWithBackgroundService() async {
    try {
      final backgroundSteps = await _backgroundService.getBackgroundSteps();
      if (backgroundSteps > _dailySteps) {
        final difference = backgroundSteps - _dailySteps;
        if (kDebugMode) print('🔄 Syncing $difference steps from background');
        
        _dailySteps = backgroundSteps;
        _sessionSteps += difference;
        _emitStepUpdate();
      }
    } catch (e) {
      if (kDebugMode) print('❌ Background sync failed: $e');
    }
  }

  /// Initialize activity recognition service
  Future<void> _initializeActivityRecognition() async {
    try {
      _activitySub = FlutterActivityRecognition.instance.activityStream.listen(
        _onActivityUpdate,
        onError: (error) {
          _analytics.logError('activity_recognition_error', error.toString());
          if (kDebugMode) print('🚨 Activity Recognition error: $error');
          _activityState = ActivityState.unknown;
        }
      );
    } catch (e) {
      _analytics.logError('activity_recognition_init_failed', e.toString());
      if (kDebugMode) print('⚠️ Activity Recognition not available: $e');
      _activityState = ActivityState.unknown;
    }
  }

  /// Initialize sensor streams (pedometer primary, accelerometer fallback)
  Future<void> _initializeSensorStreams() async {
    try {
      // Try pedometer first - it's much more reliable
      await _initializePedometer();
      
      // Initialize accelerometer as fallback for additional filtering
      await _initializeAccelerometerFallback();
      
      _analytics.logEvent('sensor_streams_initialized');
    } catch (e) {
      _analytics.logError('sensor_init_failed', e.toString());
      if (kDebugMode) print('❌ Sensor initialization failed: $e');
    }
  }
  
  /// Initialize pedometer as primary step detection
  Future<void> _initializePedometer() async {
    try {
      _pedometerSub = Pedometer.stepCountStream.listen(
        _onPedometerStep,
        onError: (error) {
          _analytics.logError('pedometer_error', error.toString());
          if (kDebugMode) print('🚨 Pedometer error: $error');
        }
      );
      
      if (kDebugMode) print('✅ Pedometer initialized successfully');
    } catch (e) {
      _analytics.logError('pedometer_init_failed', e.toString());
      if (kDebugMode) print('❌ Pedometer initialization failed: $e');
    }
  }
  
  /// Initialize accelerometer as fallback for additional context
  Future<void> _initializeAccelerometerFallback() async {
    try {
      // Initialize advanced step detection algorithm for fallback
      _stepDetector.onStepDetected = (timestamp, confidence) {
        if (kDebugMode) {
          print('🔍 Fallback algorithm detected step: confidence=${confidence.toStringAsFixed(2)}');
        }
        // Only use as fallback if pedometer is not working
        if (_pedometerSub == null) {
          _onPotentialStep(timestamp);
        }
      };
      
      // Use accelerometer for activity context and fallback
      _accelerometerSub = userAccelerometerEvents.listen(
        _onAccelerometerEvent,
        onError: (error) {
          _analytics.logError('accelerometer_error', error.toString());
          if (kDebugMode) print('🚨 Accelerometer error: $error');
        }
      );
      
      if (kDebugMode) print('✅ Accelerometer fallback initialized');
    } catch (e) {
      _analytics.logError('accelerometer_fallback_failed', e.toString());
      if (kDebugMode) print('❌ Accelerometer fallback failed: $e');
    }
  }

  /// Handle activity recognition updates
  void _onActivityUpdate(Activity activity) {
    _lastActivityUpdate = DateTime.now().millisecondsSinceEpoch;
    
    ActivityState newState;
    switch (activity.type) {
      case ActivityType.WALKING:
        newState = ActivityState.walking;
        break;
      case ActivityType.RUNNING:
        newState = ActivityState.running;
        break;
      case ActivityType.IN_VEHICLE:
        newState = ActivityState.vehicle;
        _onVehicleDetected();
        break;
      case ActivityType.STILL:
        newState = ActivityState.still;
        break;
      case ActivityType.ON_BICYCLE:
        newState = ActivityState.vehicle;
        _onVehicleDetected();
        break;
      default:
        newState = ActivityState.unknown;
    }

    if (_activityState != newState) {
      _activityState = newState;
      _analytics.logActivityChange(_activityState, activity.confidence.index);
      if (kDebugMode) {
        print('📡 Activity: $_activityState (confidence: ${activity.confidence})');
      }
    }
  }

  /// Handle vehicle detection for anomaly filtering
  void _onVehicleDetected() {
    _lastVehicleDetection = DateTime.now().millisecondsSinceEpoch;
    if (kDebugMode) print('🚗 Vehicle detected - step counting paused');
  }
  
  /// Handle pedometer step events - simplified approach like StepTrackingService
  void _onPedometerStep(StepCount stepCount) {
    if (!_isTracking) return;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Simple debouncing - reject too-fast duplicates
    if (now - _lastStepTimestamp < 250) return; // 250ms minimum between steps
    
    _lastStepTimestamp = now;
    
    // Simple step counting - just count every valid step from pedometer like StepTrackingService
    _dailySteps++;
    _sessionSteps++;
    
    final stepEvent = StepEvent(
      timestamp: now,
      totalSteps: _dailySteps,
      activityState: _activityState,
      boutActive: true,
    );
    
    _stepEventController.add(stepEvent);
    _analytics.logValidStep(_dailySteps, _activityState);
    
    _emitStepUpdate();
    
    if (kDebugMode) {
      print('🚶 Step detected: $_dailySteps total steps today');
    }
  }
  
  /// Minimal filtering for pedometer data (much lighter than accelerometer)
  bool _passesMinimalFiltering(int timestamp) {
    // Only reject during vehicle detection cooldown
    if (timestamp - _lastVehicleDetection < _vehicleCooldown) {
      return false;
    }
    
    // Very basic timing check - reject only extremely rapid steps
    if (_lastStepTimestamp > 0 && (timestamp - _lastStepTimestamp) < 100) {
      return false;
    }
    
    return true;
  }

  /// Process accelerometer data for step detection
  void _onAccelerometerEvent(UserAccelerometerEvent event) {
    if (!_isTracking) return;

    // Pass data to advanced step detection algorithm
    final now = DateTime.now().millisecondsSinceEpoch;
    _stepDetector.processAccelerometerData(event.x, event.y, event.z, now);
  }

  /// Process a potential step event through all filters
  void _onPotentialStep(int timestamp) {
    // Layer 1: Activity Gate Filter
    if (!_passesActivityGateFilter()) {
      _analytics.incrementRejection('activity_gate');
      return;
    }

    // Layer 2: Timing and debounce filter
    if (!_passesTimingFilter(timestamp)) {
      _analytics.incrementRejection('timing_filter');
      return;
    }

    // Layer 3: Vehicle spike filter
    if (!_passesVehicleFilter(timestamp)) {
      _analytics.incrementRejection('vehicle_filter');
      return;
    }

    // Layer 4: Shake burst filter
    if (!_passesShakeBurstFilter(timestamp)) {
      _analytics.incrementRejection('shake_burst');
      return;
    }

    // If we get here, it's a valid step candidate
    _processValidStep(timestamp);
  }

  /// Layer 1: Activity Gate Filter
  bool _passesActivityGateFilter() {
    // Only allow steps during walking or running
    // Also allow if activity is unknown (fallback behavior)
    switch (_activityState) {
      case ActivityState.walking:
      case ActivityState.running:
        return true;
      case ActivityState.unknown:
        // Allow if we haven't received recent AR updates (sensor might be unavailable)
        final timeSinceLastUpdate = DateTime.now().millisecondsSinceEpoch - _lastActivityUpdate;
        return timeSinceLastUpdate > 30000; // 30 seconds
      default:
        return false;
    }
  }

  /// Layer 2: Timing Filter (basic debounce)
  bool _passesTimingFilter(int timestamp) {
    return timestamp - _lastStepTimestamp >= _minStepInterval;
  }

  /// Layer 3: Vehicle Filter
  bool _passesVehicleFilter(int timestamp) {
    return timestamp - _lastVehicleDetection >= _vehicleCooldown;
  }

  /// Layer 4: Shake Burst Filter
  bool _passesShakeBurstFilter(int timestamp) {
    // Remove old timestamps outside the burst window
    _recentStepTimestamps.removeWhere(
      (ts) => timestamp - ts > _burstTimeWindow
    );

    // Check if we're exceeding the burst threshold
    if (_recentStepTimestamps.length >= _maxBurstSteps) {
      if (kDebugMode) print('❌ Shake burst detected - rejecting step');
      return false;
    }

    _recentStepTimestamps.add(timestamp);
    return true;
  }

  /// Process a validated step - simplified continuous counting
  void _processValidStep(int timestamp) {
    _lastStepTimestamp = timestamp;
    
    // Simple cadence validation (only reject extremely fast steps)
    if (_validateBasicCadence(timestamp)) {
      // Count step immediately - no bout logic needed
      _dailySteps++;
      _sessionSteps++;
      _emitStepUpdate();
      
      final stepEvent = StepEvent(
        timestamp: timestamp,
        totalSteps: _dailySteps,
        activityState: _activityState,
        boutActive: true, // Always consider as active for UI purposes
      );
      
      _stepEventController.add(stepEvent);
      _analytics.logValidStep(_dailySteps, _activityState);
      
      if (kDebugMode) print('✅ Step counted: $_dailySteps');
    } else {
      _analytics.incrementRejection('cadence_validation');
      if (kDebugMode) print('❌ Step rejected: too fast');
    }
  }

  /// Basic cadence validation (simplified)
  bool _validateBasicCadence(int timestamp) {
    if (_lastStepTimestamp == 0) return true;
    
    final interval = timestamp - _lastStepTimestamp;
    // Only reject extremely fast steps (faster than 300 spm)
    return interval >= 200; // 200ms minimum interval
  }




  /// Emit step update and persist data
  void _emitStepUpdate() {
    _stepsController.add(_dailySteps);
    _persistSteps();
  }

  /// Start step tracking
  Future<void> startTracking() async {
    if (!_initialized) {
      final success = await initialize();
      if (!success) return;
    }

    if (_isTracking) return;

    _isTracking = true;
    
    // Start background step counting
    try {
      final backgroundStarted = await _backgroundService.startBackgroundCounting();
      if (backgroundStarted) {
        if (kDebugMode) print('✅ Background step counting started');
      } else {
        if (kDebugMode) print('⚠️ Background step counting failed to start');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Background step service error: $e');
    }
    
    _analytics.logEvent('tracking_started');
    
    if (kDebugMode) print('✅ Production step counter started');
  }

  /// Stop step tracking
  void stopTracking() {
    _isTracking = false;
    _analytics.logEvent('tracking_stopped');
    
    // Note: We don't stop background service here as it should continue running
    // even when the main app is stopped. Call stopBackgroundCounting() explicitly if needed.
    
    if (kDebugMode) print('🛑 Production step counter stopped (background continues)');
  }
  
  /// Stop background step counting (call this only when user explicitly disables it)
  Future<void> stopBackgroundCounting() async {
    try {
      await _backgroundService.stopBackgroundCounting();
      if (kDebugMode) print('🛑 Background step counting stopped');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to stop background counting: $e');
    }
  }
  
  /// Check if background service is running
  Future<bool> isBackgroundServiceRunning() async {
    return await _backgroundService.isBackgroundServiceRunning();
  }

  /// Reset daily steps at midnight
  void _resetDailySteps() {
    final previousDailySteps = _dailySteps;
    
    // Add yesterday's steps to total before resetting daily counter
    _totalSteps += previousDailySteps;
    _dailySteps = 0;
    _lastDate = DateTime.now();
    
    _emitStepUpdate();
    _analytics.logDailyReset(previousDailySteps);
    
    if (kDebugMode) print('🔄 Daily reset: $previousDailySteps steps yesterday, new total: $_totalSteps');
  }

  /// Check if daily reset is needed
  void _checkDailyReset() {
    final now = DateTime.now();
    if (now.day != _lastDate.day || 
        now.month != _lastDate.month || 
        now.year != _lastDate.year) {
      _resetDailySteps();
    }
  }

  /// Persist step data
  Future<void> _persistSteps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('daily_steps', _dailySteps);
      await prefs.setInt('total_steps', _totalSteps);
      await prefs.setString('last_date', _lastDate.toIso8601String());
      // Remove bout-related persistence
    } catch (e) {
      _analytics.logError('persistence_failed', e.toString());
      if (kDebugMode) print('❌ Failed to persist steps: $e');
    }
  }

  /// Load persisted step data
  Future<void> _loadPersistedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _dailySteps = prefs.getInt('daily_steps') ?? 0;
      _totalSteps = prefs.getInt('total_steps') ?? 0;
      
      final savedDate = prefs.getString('last_date');
      if (savedDate != null) {
        _lastDate = DateTime.tryParse(savedDate) ?? DateTime.now();
      }
      
      // Remove bout-related loading
      
      // Check if we need to reset for a new day
      _checkDailyReset();
      
      // Emit initial step count
      _stepsController.add(_dailySteps);
      
      if (kDebugMode) print('📖 Loaded persisted data: $_dailySteps today steps, $_totalSteps total steps');
    } catch (e) {
      _analytics.logError('load_persisted_failed', e.toString());
      if (kDebugMode) print('❌ Failed to load persisted data: $e');
    }
  }

  /// Get current step analytics
  StepCounterMetrics getMetrics() {
    final algorithmState = _stepDetector.getState();
    return StepCounterMetrics(
      dailySteps: _dailySteps,
      boutActive: true, // Always active now
      activityState: _activityState,
      consecutiveSteps: 0, // No longer used
      lastStepTimestamp: _lastStepTimestamp,
      algorithmState: algorithmState,
    );
  }

  /// Manually add steps (for testing or external integration)
  void addSteps(int steps, {String source = 'manual'}) {
    _dailySteps += steps;
    _emitStepUpdate();
    _analytics.logManualSteps(steps, source);
    
    if (kDebugMode) print('➕ Manual steps added: $steps (total: $_dailySteps)');
  }
  
  /// Reset all step data and start fresh (clears persisted data)
  Future<void> resetAllStepData() async {
    try {
      // Clear in-memory data
      _dailySteps = 0;
      _totalSteps = 0;
      _sessionSteps = 0;
      _lastDate = DateTime.now();
      
      // Clear persisted data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('daily_steps');
      await prefs.remove('total_steps');
      await prefs.remove('last_date');
      
      // Also clear old keys that might be lingering
      await prefs.remove('dailySteps'); // Old key from StepTrackingService
      await prefs.remove('lastDate'); // Old key from StepTrackingService
      
      // Emit updated step count
      _emitStepUpdate();
      
      if (kDebugMode) print('🔄 All step data reset - starting fresh');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to reset step data: $e');
    }
  }

  /// Debug method to inject accelerometer data for testing
  void debugInjectAccelerometerData(double x, double y, double z) {
    if (!kDebugMode) return;
    
    // Pass data directly to step detection algorithm for testing
    final now = DateTime.now().millisecondsSinceEpoch;
    _stepDetector.processAccelerometerData(x, y, z, now);
  }

  /// Dispose of all resources
  void dispose() {
    stopTracking();
    _activitySub?.cancel();
    _accelerometerSub?.cancel();
    _pedometerSub?.cancel();
    _backgroundStepSub?.cancel();
    _stepDetector.dispose();
    _stepsController.close();
    _stepEventController.close();
    _analytics.dispose();
    _backgroundService.dispose(); // Background service continues running
  }
}


/// Step counter metrics for monitoring
class StepCounterMetrics {
  final int dailySteps;
  final bool boutActive;
  final ActivityState activityState;
  final int consecutiveSteps;
  final int lastStepTimestamp;
  final AlgorithmState? algorithmState;

  StepCounterMetrics({
    required this.dailySteps,
    required this.boutActive,
    required this.activityState,
    required this.consecutiveSteps,
    required this.lastStepTimestamp,
    this.algorithmState,
  });

  Map<String, dynamic> toJson() {
    final json = {
      'daily_steps': dailySteps,
      'bout_active': boutActive,
      'activity_state': activityState.toString(),
      'consecutive_steps': consecutiveSteps,
      'last_step_timestamp': lastStepTimestamp,
    };
    
    if (algorithmState != null) {
      json['algorithm_state'] = algorithmState!.toJson();
    }
    
    return json;
  }
}
