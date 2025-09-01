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
  int _sessionSteps = 0;
  int get dailySteps => _dailySteps;
  int get totalSteps => _dailySteps;
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

    Map<Permission, PermissionStatus> statuses = await permissions.request();
    
    bool allGranted = statuses.values.every(
      (status) => status == PermissionStatus.granted
    );

    if (!allGranted) {
      if (kDebugMode) {
        print('❌ Required permissions not granted:');
        statuses.forEach((permission, status) {
          print('  $permission: $status');
        });
      }
    }

    return allGranted;
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
  
  /// Handle pedometer step events - primary step detection method
  void _onPedometerStep(StepCount stepCount) {
    if (!_isTracking) return;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final currentPedometerSteps = stepCount.steps;
    
    // Initialize baseline on first reading
    if (_pedometerBaseline == 0) {
      _pedometerBaseline = currentPedometerSteps - _dailySteps;
      _lastPedometerSteps = currentPedometerSteps;
      if (kDebugMode) print('📊 Pedometer baseline set: $_pedometerBaseline');
      return;
    }
    
    // Calculate new steps since last reading
    final newSteps = currentPedometerSteps - _lastPedometerSteps;
    _lastPedometerSteps = currentPedometerSteps;
    
    if (newSteps <= 0) return; // No new steps
    
    // Apply minimal filtering for very rapid bursts
    if (newSteps > 10) {
      // Likely a pedometer reset or anomaly - reject
      if (kDebugMode) print('❌ Pedometer anomaly detected: $newSteps steps at once');
      return;
    }
    
    // Add the new steps
    for (int i = 0; i < newSteps; i++) {
      // Use minimal filtering - pedometer is already quite accurate
      if (_passesMinimalFiltering(now)) {
        _dailySteps++;
        _sessionSteps++;
        _lastStepTimestamp = now;
        
        final stepEvent = StepEvent(
          timestamp: now,
          totalSteps: _dailySteps,
          activityState: _activityState,
          boutActive: true,
        );
        
        _stepEventController.add(stepEvent);
        _analytics.logValidStep(_dailySteps, _activityState);
      }
    }
    
    _emitStepUpdate();
    
    if (kDebugMode && newSteps > 0) {
      print('🚶 Pedometer: +$newSteps steps (total: $_dailySteps)');
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
    _analytics.logEvent('tracking_started');
    
    if (kDebugMode) print('✅ Production step counter started');
  }

  /// Stop step tracking
  void stopTracking() {
    _isTracking = false;
    _analytics.logEvent('tracking_stopped');
    
    if (kDebugMode) print('🛑 Production step counter stopped');
  }

  /// Reset daily steps at midnight
  void _resetDailySteps() {
    final previousSteps = _dailySteps;
    _dailySteps = 0;
    _lastDate = DateTime.now();
    
    _emitStepUpdate();
    _analytics.logDailyReset(previousSteps);
    
    if (kDebugMode) print('🔄 Daily reset: $previousSteps steps yesterday');
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
      
      final savedDate = prefs.getString('last_date');
      if (savedDate != null) {
        _lastDate = DateTime.tryParse(savedDate) ?? DateTime.now();
      }
      
      // Remove bout-related loading
      
      // Check if we need to reset for a new day
      _checkDailyReset();
      
      // Emit initial step count
      _stepsController.add(_dailySteps);
      
      if (kDebugMode) print('📖 Loaded persisted data: $_dailySteps steps');
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
    _stepDetector.dispose();
    _stepsController.close();
    _stepEventController.close();
    _analytics.dispose();
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
