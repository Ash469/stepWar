import 'dart:async';
import 'package:flutter/foundation.dart';
class StepStateManager {
  static final StepStateManager _instance = StepStateManager._internal();
  factory StepStateManager() => _instance;
  StepStateManager._internal();

  // Current step state
  int _dailySteps = 0;
  int _totalSteps = 0;
  int _sessionSteps = 0;
  DateTime _lastUpdateTime = DateTime.now();
  
  // Stream controllers for broadcasting updates
  final StreamController<int> _dailyStepsController = StreamController<int>.broadcast();
  final StreamController<int> _totalStepsController = StreamController<int>.broadcast();
  final StreamController<StepUpdateEvent> _stepUpdateController = StreamController<StepUpdateEvent>.broadcast();
  
  // Debouncing timer to prevent too frequent updates
  Timer? _updateTimer;
  final Duration _debounceDuration = const Duration(milliseconds: 500);
  
  // Pending updates queue
  final Set<String> _pendingUpdates = <String>{};

  // Getters for current state
  int get dailySteps => _dailySteps;
  int get totalSteps => _totalSteps;
  int get sessionSteps => _sessionSteps;
  DateTime get lastUpdateTime => _lastUpdateTime;

  // Streams for listening to changes
  Stream<int> get dailyStepsStream => _dailyStepsController.stream;
  Stream<int> get totalStepsStream => _totalStepsController.stream;
  Stream<StepUpdateEvent> get stepUpdateStream => _stepUpdateController.stream;

  /// Update daily steps with debouncing to prevent rapid updates
  void updateDailySteps(int newSteps, {String source = 'unknown'}) {
    if (newSteps == _dailySteps) return; // No change, skip update
    
    final oldSteps = _dailySteps;
    _dailySteps = newSteps;
    _lastUpdateTime = DateTime.now();
    
    if (kDebugMode) {
      print('📊 Step state updated: $oldSteps → $_dailySteps (source: $source)');
    }
    
    // Cancel existing timer and start a new one to debounce updates
    _updateTimer?.cancel();
    _updateTimer = Timer(_debounceDuration, () {
      _broadcastUpdates(source);
    });
  }

  /// Update total steps
  void updateTotalSteps(int newTotal, {String source = 'unknown'}) {
    if (newTotal == _totalSteps) return;
    
    _totalSteps = newTotal;
    _lastUpdateTime = DateTime.now();
    
    if (kDebugMode) {
      print('📈 Total steps updated: $_totalSteps (source: $source)');
    }
    
    _totalStepsController.add(_totalSteps);
  }

  /// Update session steps
  void updateSessionSteps(int newSession, {String source = 'unknown'}) {
    if (newSession == _sessionSteps) return;
    
    _sessionSteps = newSession;
    _lastUpdateTime = DateTime.now();
    
    if (kDebugMode) {
      print('🏃 Session steps updated: $_sessionSteps (source: $source)');
    }
  }

  /// Add steps to current daily count
  void addSteps(int additionalSteps, {String source = 'unknown'}) {
    if (additionalSteps <= 0) return;
    
    final newDailySteps = _dailySteps + additionalSteps;
    final newTotalSteps = _totalSteps + additionalSteps;
    
    _dailySteps = newDailySteps;
    _totalSteps = newTotalSteps;
    _sessionSteps += additionalSteps;
    _lastUpdateTime = DateTime.now();
    
    if (kDebugMode) {
      print('➕ Added $additionalSteps steps (source: $source)');
      print('   Daily: $_dailySteps, Total: $_totalSteps, Session: $_sessionSteps');
    }
    
    // Debounced broadcast
    _updateTimer?.cancel();
    _updateTimer = Timer(_debounceDuration, () {
      _broadcastUpdates(source);
    });
  }

  /// Initialize step counts (typically from persistence or Firebase)
  void initializeSteps({
    required int dailySteps,
    required int totalSteps,
    int sessionSteps = 0,
    String source = 'initialization',
  }) {
    _dailySteps = dailySteps;
    _totalSteps = totalSteps;
    _sessionSteps = sessionSteps;
    _lastUpdateTime = DateTime.now();
    
    if (kDebugMode) {
      print('🔄 Step state initialized (source: $source)');
      print('   Daily: $_dailySteps, Total: $_totalSteps, Session: $_sessionSteps');
    }
    
    // Immediate broadcast for initialization
    _broadcastUpdates(source, immediate: true);
  }

  /// Reset daily steps (for new day)
  void resetDailySteps({String source = 'day_reset'}) {
    _dailySteps = 0;
    _sessionSteps = 0;
    _lastUpdateTime = DateTime.now();
    
    if (kDebugMode) {
      print('🔄 Daily steps reset (source: $source)');
    }
    
    _broadcastUpdates(source, immediate: true);
  }

  /// Broadcast updates to all listeners
  void _broadcastUpdates(String source, {bool immediate = false}) {
    if (!immediate && _pendingUpdates.contains(source)) {
      return; // Already pending update from this source
    }
    
    _pendingUpdates.add(source);
    
    // Broadcast to streams
    _dailyStepsController.add(_dailySteps);
    _totalStepsController.add(_totalSteps);
    _stepUpdateController.add(StepUpdateEvent(
      dailySteps: _dailySteps,
      totalSteps: _totalSteps,
      sessionSteps: _sessionSteps,
      source: source,
      timestamp: _lastUpdateTime,
    ));
    
    if (kDebugMode) {
      print('📡 Step updates broadcasted (source: $source)');
    }
    
    // Clear pending updates after a short delay
    Timer(const Duration(milliseconds: 100), () {
      _pendingUpdates.remove(source);
    });
  }

  /// Force immediate update broadcast
  void forceBroadcast({String source = 'force'}) {
    _broadcastUpdates(source, immediate: true);
  }

  /// Register a service for updates to prevent duplicate processing
  void registerService(String serviceName) {
    if (kDebugMode) {
      print('🔌 Service registered: $serviceName');
    }
  }

  /// Unregister a service
  void unregisterService(String serviceName) {
    if (kDebugMode) {
      print('🔌 Service unregistered: $serviceName');
    }
  }

  /// Get current state as a map
  Map<String, dynamic> getCurrentState() {
    return {
      'dailySteps': _dailySteps,
      'totalSteps': _totalSteps,
      'sessionSteps': _sessionSteps,
      'lastUpdateTime': _lastUpdateTime.toIso8601String(),
    };
  }

  /// Dispose of the manager
  void dispose() {
    _updateTimer?.cancel();
    _dailyStepsController.close();
    _totalStepsController.close();
    _stepUpdateController.close();
    _pendingUpdates.clear();
    
    if (kDebugMode) {
      print('🗑️ Step state manager disposed');
    }
  }
}

/// Event class for step updates
class StepUpdateEvent {
  final int dailySteps;
  final int totalSteps;
  final int sessionSteps;
  final String source;
  final DateTime timestamp;

  const StepUpdateEvent({
    required this.dailySteps,
    required this.totalSteps,
    required this.sessionSteps,
    required this.source,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'StepUpdateEvent(daily: $dailySteps, total: $totalSteps, session: $sessionSteps, source: $source)';
  }
}
