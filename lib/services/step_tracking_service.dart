import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import 'persistence_service.dart';
import 'step_state_manager.dart';
import 'foreground_step_service.dart';
import 'auth_service.dart';
import 'game_manager_service.dart';
import 'firestore_service.dart';

class StepTrackingService {
  static final StepTrackingService _instance = StepTrackingService._internal();
  factory StepTrackingService() => _instance;
  StepTrackingService._internal();

  // Use centralized state manager instead of local state
  final StepStateManager _stateManager = StepStateManager();
  
  // Expose streams from state manager
  Stream<int> get stepsStream => _stateManager.dailyStepsStream;
  Stream<StepUpdateEvent> get stepUpdateStream => _stateManager.stepUpdateStream;

  // Expose getters from state manager
  int get dailySteps => _stateManager.dailySteps;
  int get totalSteps => _stateManager.totalSteps;
  int get sessionSteps => _stateManager.sessionSteps;

  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<User?>? _authSubscription;
  bool _initialized = false;
  bool _notificationsEnabled = false;
  bool _isAuthenticated = false;

  // Service instances
  final NotificationService _notificationService = NotificationService();
  final ForegroundStepService _foregroundService = ForegroundStepService();
  final PersistenceService _persistence = PersistenceService();
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final GameManagerService _gameManager = GameManagerService();

  // Simple debouncing
  int _lastStepTs = 0;
  final int _minStepMs = 250;

  DateTime _lastDate = DateTime.now();
  StreamSubscription<StepUpdateEvent>? _stateSubscription;

  Future<void> _initializeServices() async {
    await _firestoreService.initialize();
    await _gameManager.initialize();
  }

  /// Initialize sensor permissions
  Future<bool> initialize() async {
    // Prevent reinitialization
    if (_initialized) {
      if (kDebugMode) print("🔄 StepTrackingService already initialized with ${_stateManager.dailySteps} steps");
      return true;
    }
    
    await _initializeServices();
    
    // Register this service with state manager
    _stateManager.registerService('StepTrackingService');
    
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
    
    // Listen to authentication state changes
    await _authService.initialize();
    _authSubscription = _authService.authStateChanges.listen(_onAuthStateChanged);
    
    // Check current authentication state
    _isAuthenticated = _authService.isSignedIn;
    
    // Listen to state manager updates for persistence and notifications
    _stateSubscription = _stateManager.stepUpdateStream.listen(_onStateUpdate);
    
    _initialized = true;
    
    if (kDebugMode) {
      print("✅ StepTrackingService initialized with all permissions granted - ${_stateManager.dailySteps} daily, ${_stateManager.totalSteps} total steps");
      print("🔐 Authentication status: ${_isAuthenticated ? 'Authenticated' : 'Not authenticated'}");
    }
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

      if (kDebugMode) print("✅ StepTrackingService started tracking from ${_stateManager.dailySteps} steps");
    } catch (e) {
      if (kDebugMode) print("❌ Failed to start step tracking: $e");
    }
  }

  /// Handle authentication state changes
  void _onAuthStateChanged(User? user) {
    final wasAuthenticated = _isAuthenticated;
    _isAuthenticated = user != null;
    
    if (kDebugMode) {
      print('🔐 Authentication state changed: ${_isAuthenticated ? 'Authenticated' : 'Not authenticated'}');
    }
    
    if (_isAuthenticated && !wasAuthenticated) {
      // User just logged in - Firebase sync service will handle step initialization
      if (kDebugMode) print('✅ User logged in - step tracking now active');
    } else if (!_isAuthenticated && wasAuthenticated) {
      // User just logged out - reset step data locally
      _stateManager.initializeSteps(
        dailySteps: 0,
        totalSteps: 0,
        sessionSteps: 0,
        source: 'logout_reset',
      );
      if (kDebugMode) print('🗑️ User logged out - steps reset to 0');
    }
  }

  /// Handle each pedometer step
  void _onStepDetected(StepCount stepCount) {
    final ts = stepCount.timeStamp.millisecondsSinceEpoch;
    final currentSteps = stepCount.steps;

    // ONLY COUNT STEPS IF USER IS AUTHENTICATED
    if (!_isAuthenticated) {
      if (kDebugMode) print('🚫 Step ignored - user not authenticated');
      return;
    }

    // Reject too-fast duplicates (basic debounce)
    if (ts - _lastStepTs < _minStepMs) return;

    // ✅ compute delta BEFORE updating _lastStepTs
    final delta = _lastStepTs == 0 ? _minStepMs : (ts - _lastStepTs);
    _lastStepTs = ts;

    // Use state manager to add step - this will handle debouncing and broadcasting
    _stateManager.addSteps(1, source: 'pedometer');
    
    if (kDebugMode) print("🚶 Step detected: ${_stateManager.dailySteps} daily, ${_stateManager.totalSteps} total steps (raw: $currentSteps)");
  }


  /// Handle state updates from the centralized manager
  void _onStateUpdate(StepUpdateEvent event) {
    // Only handle updates from sources other than this service to avoid loops
    if (event.source == 'pedometer') return;
    
    if (kDebugMode) {
      print('📡 Step state update received: ${event.dailySteps} daily, ${event.totalSteps} total (from: ${event.source})');
    }
    
    // Update notification and persistence when state changes
    _updateNotification();
    _persistStepsFromState();
  }

  /// Reset steps at midnight
  void _resetDailySteps() {
    final previousDailySteps = _stateManager.dailySteps;
    
    // Save yesterday's step history
    if (previousDailySteps > 0) {
      _persistence.saveStepHistory(_lastDate, previousDailySteps);
    }
    
    // Use state manager to reset
    _stateManager.resetDailySteps(source: 'midnight_reset');
    _lastDate = DateTime.now();
    
    if (kDebugMode) print('🔄 Daily reset: $previousDailySteps steps yesterday, ${_stateManager.totalSteps} total steps');
  }

  /// Persist step count using PersistenceService from state manager
  Future<void> _persistStepsFromState() async {
    try {
      await _persistence.saveStepData(
        dailySteps: _stateManager.dailySteps,
        totalSteps: _stateManager.totalSteps,
        sessionSteps: _stateManager.sessionSteps,
        lastDate: _lastDate,
        notificationsEnabled: _notificationsEnabled,
      );
      if (kDebugMode) print('💾 Step data saved: daily=${_stateManager.dailySteps}, total=${_stateManager.totalSteps}');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to persist steps: $e');
    }
  }

  /// Load persisted step count and initialize state manager
  Future<void> _loadPersistedSteps() async {
    try {
      final stepData = _persistence.loadStepData();
      final dailySteps = stepData['dailySteps'] as int;
      final totalSteps = stepData['totalSteps'] as int;
      _lastDate = stepData['lastDate'] as DateTime;
      _notificationsEnabled = stepData['notificationsEnabled'] as bool;
      
      // Reset if saved date is from a different day
      final now = DateTime.now();
      if (now.day != _lastDate.day || 
          now.month != _lastDate.month || 
          now.year != _lastDate.year) {
        // New day - reset daily steps but keep total
        _stateManager.initializeSteps(
          dailySteps: 0,
          totalSteps: totalSteps + dailySteps, // Add yesterday's steps to total
          sessionSteps: 0,
          source: 'new_day_initialization',
        );
        _lastDate = now;
      } else {
        // Same day - restore saved state
        _stateManager.initializeSteps(
          dailySteps: dailySteps,
          totalSteps: totalSteps,
          sessionSteps: 0, // Always start fresh session
          source: 'persistence_restore',
        );
      }
      
      if (kDebugMode) print('📆 Loaded persisted steps: ${_stateManager.dailySteps} daily, ${_stateManager.totalSteps} total');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to load persisted steps: $e');
      // Use defaults
      _stateManager.initializeSteps(
        dailySteps: 0,
        totalSteps: 0,
        sessionSteps: 0,
        source: 'default_initialization',
      );
      _lastDate = DateTime.now();
    }
  }

  /// Enable persistent notifications using foreground service
  Future<void> enableNotifications() async {
    // Start foreground service for truly sticky notification
    final success = await _foregroundService.startForegroundService();
    if (success) {
      _notificationsEnabled = true;
      _updateNotification(); // Show initial notification with current steps
      if (kDebugMode) print("🔔 Step notifications enabled with foreground service");
    } else {
      // Fallback to regular notification service
      final fallbackSuccess = await _notificationService.initialize();
      if (fallbackSuccess) {
        _notificationsEnabled = true;
        _updateNotification();
        if (kDebugMode) print("🔔 Step notifications enabled with fallback service");
      }
    }
  }

  /// Disable persistent notifications
  Future<void> disableNotifications() async {
    _notificationsEnabled = false;
    await _foregroundService.stopForegroundService();
    await _notificationService.hideStepTrackingNotification();
    if (kDebugMode) print("🔕 Step notifications disabled");
  }

  /// Update the persistent notification with current step count
  void _updateNotification() {
    if (_notificationsEnabled) {
      if (_foregroundService.isRunning) {
        _foregroundService.updateNotification(_stateManager.dailySteps);
      } else {
        _notificationService.showStepTrackingNotification(_stateManager.dailySteps);
      }
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
    _stateManager.addSteps(steps, source: source);
    if (kDebugMode) print('➕ Manual steps added: $steps (daily: ${_stateManager.dailySteps}, total: ${_stateManager.totalSteps}) from $source');
  }

  /// Convert steps to attack points
  Future<bool> convertStepsToAttackPoints(int stepsToConvert) async {
    if (!_isAuthenticated) return false;
    
    try {
      // Check if we have enough steps
      if (stepsToConvert > _stateManager.dailySteps) {
        if (kDebugMode) print('⚠️ Not enough steps to convert: ${_stateManager.dailySteps} available');
        return false;
      }

      // Calculate attack points (10 steps = 1 attack point)
      final attackPoints = stepsToConvert ~/ 10;

      if (attackPoints > 0) {
        // Use state manager to deduct steps
        final success = await _stateManager.convertStepsToAttackPoints(stepsToConvert);
        
        if (success) {
          if (kDebugMode) {
            print('✅ Converted $stepsToConvert steps to $attackPoints attack points');
            print('   Remaining steps: ${_stateManager.dailySteps}');
          }
          
          // Update persistence and sync
          await _persistStepsFromState();
          return true;
        }
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) print('❌ Error converting steps to attack points: $e');
      return false;
    }
  }

  /// Convert attack points to shield points
  Future<int> convertAttackPointsToShield(int attackPointsToConvert) async {
    if (!_isAuthenticated) return 0;
    
    try {
      final gameManager = GameManagerService();
      final currentUser = await gameManager.getCurrentUser();
      if (currentUser == null) return 0;
      
      final shieldPoints = await gameManager.convertAttackPointsToShield(
        currentUser.id,
        attackPointsToConvert,
      );
      
      if (kDebugMode && shieldPoints > 0) {
        print('✅ Converted $attackPointsToConvert attack points to $shieldPoints shield points');
      }
      
      return shieldPoints;
    } catch (e) {
      if (kDebugMode) print('❌ Error converting attack points to shield: $e');
      return 0;
    }
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
    _stateManager.initializeSteps(
      dailySteps: 0,
      totalSteps: 0,
      sessionSteps: 0,
      source: 'manual_reset',
    );
    _lastDate = DateTime.now();
    
    if (kDebugMode) print('🔄 All step data reset');
  }
  
  void dispose() {
    stopTracking();
    _stateSubscription?.cancel();
    _authSubscription?.cancel();
    _stateManager.unregisterService('StepTrackingService');
    _foregroundService.dispose();
    _notificationService.dispose();
    if (kDebugMode) print('🗑️ StepTrackingService disposed');
  }
}
