import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ActivityState { walking, running, still, vehicle, other }

class StepTrackingService {
  static final StepTrackingService _instance = StepTrackingService._internal();
  factory StepTrackingService() => _instance;
  StepTrackingService._internal();

  final _stepsController = StreamController<int>.broadcast();
  Stream<int> get stepsStream => _stepsController.stream;

  int _dailySteps = 0;
  int get dailySteps => _dailySteps;

  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<Activity>? _activitySub;

  ActivityState _activityState = ActivityState.other;
  bool _initialized = false;

  // Bout logic
  bool _boutOn = false;
  int _consecSteps = 0;
  int _lastStepTs = 0;
  final int _nConsecutive = 6;
  final int _minStepMs = 250;
  final int _idleTimeout = 3000;

  DateTime _lastDate = DateTime.now();

  /// Initialize AR + permissions
  Future<bool> initialize() async {
    final arPerm = await Permission.activityRecognition.request();
    final sensorPerm = await Permission.sensors.request();
    if (arPerm != PermissionStatus.granted ||
        sensorPerm != PermissionStatus.granted) {
      if (kDebugMode) print("❌ Permissions not granted");
      return false;
    }

    await _loadPersistedSteps();

    // Activity Recognition subscription (Android only)
    try {
      _activitySub =
          FlutterActivityRecognition.instance.activityStream.listen((activity) {
        switch (activity.type) {
          case ActivityType.WALKING:
            _activityState = ActivityState.walking;
            break;
          case ActivityType.RUNNING:
            _activityState = ActivityState.running;
            break;
          case ActivityType.IN_VEHICLE:
            _activityState = ActivityState.vehicle;
            break;
          case ActivityType.STILL:
            _activityState = ActivityState.still;
            break;
          default:
            _activityState = ActivityState.other;
        }
        if (kDebugMode) {
          print("📡 AR update: $_activityState (raw=${activity.type})");
        }
      }, onError: (err) {
        if (kDebugMode) print("AR error: $err");
        _activityState = ActivityState.other; // fallback
      });
    } catch (e) {
      if (kDebugMode) print("⚠️ AR not available: $e");
      _activityState = ActivityState.other;
    }

    _initialized = true;
    return true;
  }

  /// Start step tracking
  Future<void> startTracking() async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    _stepSub = Pedometer.stepCountStream.listen(
      (event) => _onStepDetected(),
      onError: (err) => kDebugMode ? print("Step stream error: $err") : null,
    );

    if (kDebugMode) print("✅ StepTrackingService started");
  }

  /// Handle each pedometer step
void _onStepDetected() {
  final ts = DateTime.now().millisecondsSinceEpoch;

  // Reject too-fast duplicates (basic debounce)
  if (ts - _lastStepTs < _minStepMs) return;

  // ✅ compute delta BEFORE updating _lastStepTs
  final delta = _lastStepTs == 0 ? _minStepMs : (ts - _lastStepTs);
  _lastStepTs = ts;

  // Only count if AR says walking/running OR fallback
  if (!(_activityState == ActivityState.walking ||
      _activityState == ActivityState.running)) {
    if (kDebugMode) print("❌ Step ignored due to AR = $_activityState");
    return;
  }

  if (!_boutOn) {
    _consecSteps++;
    if (_consecSteps >= _nConsecutive) {
      _boutOn = true;
      _dailySteps += _consecSteps;
      _stepsController.add(_dailySteps);
      if (kDebugMode) print("🚶 Bout started at step $_dailySteps");
    }
  } else {
    // ✅ cadence check using delta
    final cadence = 60000 ~/ delta.clamp(1, 5000);
    if (cadence < 40 || cadence > 220) {
      if (kDebugMode) print("❌ Cadence anomaly: $cadence spm");
      return;
    }

    _dailySteps++;
    _stepsController.add(_dailySteps);
  }

  // Bout reset after idle
  Future.delayed(Duration(milliseconds: _idleTimeout), () {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastStepTs > _idleTimeout) {
      _boutOn = false;
      _consecSteps = 0;
      if (kDebugMode) print("⏹ Bout ended (idle)");
    }
  });
}


  /// Reset steps at midnight
  void _resetDailySteps() {
    _dailySteps = 0;
    _lastDate = DateTime.now();
    _stepsController.add(_dailySteps);
    _persistSteps();
    if (kDebugMode) print("🔄 Daily reset done");
  }

  /// Persist step count
  Future<void> _persistSteps() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt("dailySteps", _dailySteps);
    prefs.setString("lastDate", _lastDate.toIso8601String());
  }

  /// Load persisted step count
  Future<void> _loadPersistedSteps() async {
    final prefs = await SharedPreferences.getInstance();
    _dailySteps = prefs.getInt("dailySteps") ?? 0;
    final savedDate = prefs.getString("lastDate");
    if (savedDate != null) {
      _lastDate = DateTime.tryParse(savedDate) ?? DateTime.now();
    }
    // Reset if saved date is old
    if (DateTime.now().day != _lastDate.day) {
      _resetDailySteps();
    }
    _stepsController.add(_dailySteps);
  }

  void stopTracking() {
    _stepSub?.cancel();
    _stepSub = null;
    _activitySub?.cancel();
    _activitySub = null;
    if (kDebugMode) print("🛑 StepTrackingService stopped");
  }

  void dispose() {
    stopTracking();
    _stepsController.close();
  }
}
