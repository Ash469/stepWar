import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'step_counter_types.dart';

/// Analytics service for step counter telemetry and tuning
/// Tracks metrics to validate and improve the filtering system
class StepAnalyticsService {
  static final StepAnalyticsService _instance = StepAnalyticsService._internal();
  factory StepAnalyticsService() => _instance;
  StepAnalyticsService._internal();

  // Counters for filter rejections
  final Map<String, int> _rejectionCounts = {};
  
  // Activity state tracking
  final Map<String, int> _activityStateDurations = {};
  int _lastActivityChangeTime = 0;
  String _currentActivity = 'unknown';

  // Bout analytics
  final List<BoutMetrics> _boutHistory = [];
  int _currentBoutStartTime = 0;
  int _currentBoutSteps = 0;

  // Step validation metrics
  int _totalStepEvents = 0;
  int _acceptedSteps = 0;
  int _rejectedSteps = 0;

  // Session tracking
  int _sessionStartTime = 0;
  bool _sessionActive = false;

  /// Initialize analytics service
  void initialize() {
    _sessionStartTime = DateTime.now().millisecondsSinceEpoch;
    _sessionActive = true;
    _loadPersistedMetrics();
  }

  /// Log a generic event
  void logEvent(String eventName, [Map<String, dynamic>? parameters]) {
    if (kDebugMode) {
      print('📊 Analytics: $eventName ${parameters != null ? jsonEncode(parameters) : ''}');
    }
    
    // In production, you'd send this to your analytics service
    // For now, we'll just store locally for debugging
    _storeLocalEvent(eventName, parameters);
  }

  /// Log an error event
  void logError(String errorType, String errorMessage) {
    logEvent('error', {
      'error_type': errorType,
      'error_message': errorMessage,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Increment rejection counter for a specific filter
  void incrementRejection(String filterType) {
    _rejectionCounts[filterType] = (_rejectionCounts[filterType] ?? 0) + 1;
    _rejectedSteps++;
    _totalStepEvents++;
    
    if (kDebugMode) {
      print('📊 Rejection: $filterType (total: ${_rejectionCounts[filterType]})');
    }
  }

  /// Log activity state change
  void logActivityChange(ActivityState newState, int confidence) {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Track duration of previous activity
    if (_lastActivityChangeTime > 0) {
      final duration = now - _lastActivityChangeTime;
      final activityKey = _currentActivity;
      _activityStateDurations[activityKey] = 
          (_activityStateDurations[activityKey] ?? 0) + duration;
    }
    
    _currentActivity = newState.toString();
    _lastActivityChangeTime = now;
    
    logEvent('activity_change', {
      'new_state': newState.toString(),
      'confidence': confidence,
      'timestamp': now,
    });
  }

  /// Log bout start
  void logBoutStart(int totalSteps) {
    _currentBoutStartTime = DateTime.now().millisecondsSinceEpoch;
    _currentBoutSteps = 0;
    
    logEvent('bout_start', {
      'total_steps': totalSteps,
      'timestamp': _currentBoutStartTime,
    });
  }

  /// Log bout end
  void logBoutEnd(String reason) {
    if (_currentBoutStartTime > 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final duration = now - _currentBoutStartTime;
      
      final boutMetrics = BoutMetrics(
        startTime: _currentBoutStartTime,
        endTime: now,
        duration: duration,
        steps: _currentBoutSteps,
        endReason: reason,
      );
      
      _boutHistory.add(boutMetrics);
      
      // Keep only last 50 bouts to prevent memory bloat
      if (_boutHistory.length > 50) {
        _boutHistory.removeAt(0);
      }
      
      logEvent('bout_end', {
        'duration_ms': duration,
        'steps': _currentBoutSteps,
        'reason': reason,
        'timestamp': now,
      });
      
      _currentBoutStartTime = 0;
      _currentBoutSteps = 0;
    }
  }

  /// Log a valid step
  void logValidStep(int totalSteps, ActivityState activityState) {
    _acceptedSteps++;
    _totalStepEvents++;
    _currentBoutSteps++;
    
    // Periodically log acceptance rate
    if (_totalStepEvents % 100 == 0) {
      _logAcceptanceRate();
    }
  }

  /// Log manual steps addition
  void logManualSteps(int steps, String source) {
    logEvent('manual_steps', {
      'steps': steps,
      'source': source,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Log daily reset event
  void logDailyReset(int previousDaySteps) {
    logEvent('daily_reset', {
      'previous_day_steps': previousDaySteps,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Log current acceptance rate
  void _logAcceptanceRate() {
    if (_totalStepEvents > 0) {
      final acceptanceRate = (_acceptedSteps / _totalStepEvents * 100).round();
      logEvent('acceptance_rate', {
        'rate_percent': acceptanceRate,
        'accepted': _acceptedSteps,
        'rejected': _rejectedSteps,
        'total': _totalStepEvents,
      });
    }
  }

  /// Get comprehensive analytics report
  AnalyticsReport getReport() {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Calculate session duration
    int sessionDuration = 0;
    if (_sessionActive && _sessionStartTime > 0) {
      sessionDuration = now - _sessionStartTime;
    }

    // Calculate acceptance rate
    double acceptanceRate = 0.0;
    if (_totalStepEvents > 0) {
      acceptanceRate = _acceptedSteps / _totalStepEvents;
    }

    // Calculate average bout length
    double avgBoutDuration = 0.0;
    double avgBoutSteps = 0.0;
    if (_boutHistory.isNotEmpty) {
      avgBoutDuration = _boutHistory
          .map((b) => b.duration)
          .reduce((a, b) => a + b) / _boutHistory.length;
      avgBoutSteps = _boutHistory
          .map((b) => b.steps)
          .reduce((a, b) => a + b) / _boutHistory.length;
    }

    return AnalyticsReport(
      sessionDuration: sessionDuration,
      totalStepEvents: _totalStepEvents,
      acceptedSteps: _acceptedSteps,
      rejectedSteps: _rejectedSteps,
      acceptanceRate: acceptanceRate,
      rejectionBreakdown: Map.from(_rejectionCounts),
      activityStateDurations: Map.from(_activityStateDurations),
      totalBouts: _boutHistory.length,
      averageBoutDuration: avgBoutDuration,
      averageBoutSteps: avgBoutSteps,
      recentBouts: _boutHistory.take(10).toList(),
    );
  }

  /// Store event locally for debugging
  void _storeLocalEvent(String eventName, Map<String, dynamic>? parameters) {
    // In a production app, you'd send this to your analytics backend
    // For now, we'll store in SharedPreferences for local debugging
    
    if (!kDebugMode) return; // Only store in debug mode
    
    SharedPreferences.getInstance().then((prefs) {
      final events = prefs.getStringList('analytics_events') ?? [];
      final event = {
        'event': eventName,
        'parameters': parameters,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      events.add(jsonEncode(event));
      
      // Keep only last 100 events
      if (events.length > 100) {
        events.removeAt(0);
      }
      
      prefs.setStringList('analytics_events', events);
    });
  }

  /// Load persisted metrics
  Future<void> _loadPersistedMetrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load rejection counts
      final rejectionData = prefs.getString('rejection_counts');
      if (rejectionData != null) {
        final Map<String, dynamic> data = jsonDecode(rejectionData);
        data.forEach((key, value) {
          _rejectionCounts[key] = value as int;
        });
      }
      
      // Load step counts
      _acceptedSteps = prefs.getInt('accepted_steps') ?? 0;
      _rejectedSteps = prefs.getInt('rejected_steps') ?? 0;
      _totalStepEvents = prefs.getInt('total_step_events') ?? 0;
      
    } catch (e) {
      if (kDebugMode) print('❌ Failed to load analytics metrics: $e');
    }
  }

  /// Persist current metrics
  Future<void> _persistMetrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save rejection counts
      await prefs.setString('rejection_counts', jsonEncode(_rejectionCounts));
      
      // Save step counts
      await prefs.setInt('accepted_steps', _acceptedSteps);
      await prefs.setInt('rejected_steps', _rejectedSteps);
      await prefs.setInt('total_step_events', _totalStepEvents);
      
    } catch (e) {
      if (kDebugMode) print('❌ Failed to persist analytics metrics: $e');
    }
  }

  /// Export analytics data for analysis
  Future<String> exportAnalytics() async {
    final report = getReport();
    return jsonEncode({
      'export_timestamp': DateTime.now().toIso8601String(),
      'report': report.toJson(),
      'rejection_details': _rejectionCounts,
      'bout_history': _boutHistory.map((b) => b.toJson()).toList(),
    });
  }

  /// Clear all analytics data
  Future<void> clearAnalytics() async {
    _rejectionCounts.clear();
    _activityStateDurations.clear();
    _boutHistory.clear();
    _totalStepEvents = 0;
    _acceptedSteps = 0;
    _rejectedSteps = 0;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('rejection_counts');
    await prefs.remove('accepted_steps');
    await prefs.remove('rejected_steps');
    await prefs.remove('total_step_events');
    await prefs.remove('analytics_events');
    
    logEvent('analytics_cleared');
  }

  /// Dispose analytics service
  void dispose() {
    _persistMetrics();
  }
}

/// Bout metrics for tracking walking sessions
class BoutMetrics {
  final int startTime;
  final int endTime;
  final int duration;
  final int steps;
  final String endReason;

  BoutMetrics({
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.steps,
    required this.endReason,
  });

  Map<String, dynamic> toJson() {
    return {
      'start_time': startTime,
      'end_time': endTime,
      'duration_ms': duration,
      'steps': steps,
      'end_reason': endReason,
    };
  }
}

/// Comprehensive analytics report
class AnalyticsReport {
  final int sessionDuration;
  final int totalStepEvents;
  final int acceptedSteps;
  final int rejectedSteps;
  final double acceptanceRate;
  final Map<String, int> rejectionBreakdown;
  final Map<String, int> activityStateDurations;
  final int totalBouts;
  final double averageBoutDuration;
  final double averageBoutSteps;
  final List<BoutMetrics> recentBouts;

  AnalyticsReport({
    required this.sessionDuration,
    required this.totalStepEvents,
    required this.acceptedSteps,
    required this.rejectedSteps,
    required this.acceptanceRate,
    required this.rejectionBreakdown,
    required this.activityStateDurations,
    required this.totalBouts,
    required this.averageBoutDuration,
    required this.averageBoutSteps,
    required this.recentBouts,
  });

  Map<String, dynamic> toJson() {
    return {
      'session_duration_ms': sessionDuration,
      'total_step_events': totalStepEvents,
      'accepted_steps': acceptedSteps,
      'rejected_steps': rejectedSteps,
      'acceptance_rate': acceptanceRate,
      'rejection_breakdown': rejectionBreakdown,
      'activity_state_durations': activityStateDurations,
      'total_bouts': totalBouts,
      'average_bout_duration_ms': averageBoutDuration,
      'average_bout_steps': averageBoutSteps,
      'recent_bouts': recentBouts.map((b) => b.toJson()).toList(),
    };
  }

  /// Get human-readable summary
  String getSummary() {
    final acceptancePercent = (acceptanceRate * 100).toStringAsFixed(1);
    final avgBoutMin = (averageBoutDuration / 60000).toStringAsFixed(1);
    
    return '''
Step Counter Analytics Summary
=============================
Session Duration: ${(sessionDuration / 60000).toStringAsFixed(1)} minutes
Total Events: $totalStepEvents
Accepted: $acceptedSteps ($acceptancePercent%)
Rejected: $rejectedSteps

Rejection Breakdown:
${rejectionBreakdown.entries.map((e) => '  ${e.key}: ${e.value}').join('\n')}

Bout Statistics:
Total Bouts: $totalBouts
Average Duration: ${avgBoutMin} minutes
Average Steps per Bout: ${averageBoutSteps.toStringAsFixed(1)}

Activity Time Distribution:
${activityStateDurations.entries.map((e) => '  ${e.key}: ${(e.value / 60000).toStringAsFixed(1)} minutes').join('\n')}
''';
  }
}

