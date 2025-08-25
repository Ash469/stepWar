import 'dart:async';
import 'dart:collection';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' as math;

enum ActivityState {
  unknown,
  walking,
  running,
  onFoot,
  inVehicle,
  onBicycle,
  still,
  tilting,
}

class StepTrackingService {
  static final StepTrackingService _instance = StepTrackingService._internal();
  factory StepTrackingService() => _instance;
  StepTrackingService._internal();

  // State variables
  ActivityState _arState = ActivityState.unknown;
  bool _boutOn = false;
  int _consecSteps = 0;
  int _lastStepTs = 0;
  final Queue<int> _lastMinuteWindow = Queue<int>();
  int _dailySteps = 0;
  
  // Configuration (can be adjusted via remote config)
  int _nConsecutive = 6;
  double _cadenceMin = 40.0;
  double _cadenceMax = 220.0;
  int _idleTimeout = 3000; // 3 seconds
  int _vehicleLockout = 10000; // 10 seconds
  
  // Streams
  final StreamController<int> _stepsController = StreamController<int>.broadcast();
  Stream<int> get stepsStream => _stepsController.stream;
  
  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  Timer? _tickTimer;
  
  bool _isInitialized = false;
  bool _isTracking = false;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    // Request permissions
    final permission = await Permission.sensors.request();
    if (permission != PermissionStatus.granted) {
      return false;
    }
    
    _isInitialized = true;
    return true;
  }

  Future<void> startTracking() async {
    if (!_isInitialized || _isTracking) return;
    
    _isTracking = true;
    
    // Start accelerometer listening for step detection
    _accelerometerSubscription = userAccelerometerEvents.listen(_onAccelerometerEvent);
    
    // Start periodic tick for bout management
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _onTick(DateTime.now().millisecondsSinceEpoch);
    });
    
    // Mock activity recognition (in real app, use Google Activity Recognition)
    _startMockActivityRecognition();
  }

  void stopTracking() {
    if (!_isTracking) return;
    
    _isTracking = false;
    _accelerometerSubscription?.cancel();
    _tickTimer?.cancel();
  }

  void dispose() {
    stopTracking();
    _stepsController.close();
  }

  // Mock activity recognition for demo
  void _startMockActivityRecognition() {
    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_isTracking) {
        timer.cancel();
        return;
      }
      
      // Simulate activity state changes
      final states = [
        ActivityState.walking,
        ActivityState.running,
        ActivityState.onFoot,
        ActivityState.still,
      ];
      
      _arState = states[DateTime.now().second % states.length];
    });
  }

  void _onAccelerometerEvent(UserAccelerometerEvent event) {
    // Simple step detection based on acceleration magnitude
    final magnitude = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    
    // Threshold for step detection (tunable)
    if (magnitude > 2.0) {
      _onStepEvent(DateTime.now().millisecondsSinceEpoch);
    }
  }

  void _onActivityUpdate(ActivityState state) {
    _arState = state;
  }

  void _onStepEvent(int ts) {
    // Gate with activity recognition
    if (!{ActivityState.walking, ActivityState.running, ActivityState.onFoot}.contains(_arState)) {
      return;
    }

    // Cadence calculation (rolling 60s window)
    _lastMinuteWindow.addLast(ts);
    while (_lastMinuteWindow.isNotEmpty && ts - _lastMinuteWindow.first > 60000) {
      _lastMinuteWindow.removeFirst();
    }
    
    final cadenceSpm = _lastMinuteWindow.length * 60000.0 / 
        (ts - (_lastMinuteWindow.isNotEmpty ? _lastMinuteWindow.first : ts)).toDouble().clamp(1, double.infinity);
    
    if (cadenceSpm < _cadenceMin || cadenceSpm > _cadenceMax) {
      // Outside plausible cadence → don't start/continue bout
      _consecSteps = 0;
      if (_boutOn) _boutOn = false;
      return;
    }

    // Bout logic
    if (!_boutOn) {
      _consecSteps += 1;
      if (_consecSteps >= _nConsecutive && ts - _lastStepTs <= 10000) {
        _boutOn = true;
        // Retro-count the seed steps
        _dailySteps += _consecSteps;
        _stepsController.add(_dailySteps);
      }
    } else {
      _dailySteps += 1;
      _stepsController.add(_dailySteps);
    }

    _lastStepTs = ts;
  }

  void _onTick(int ts) {
    // End bout if idle > 3s
    if (_boutOn && ts - _lastStepTs > _idleTimeout) {
      _boutOn = false;
      _consecSteps = 0;
    }
  }

  // Getters
  int get dailySteps => _dailySteps;
  bool get isTracking => _isTracking;
  ActivityState get currentActivity => _arState;
  bool get isBoutActive => _boutOn;
  
  // For testing - manually add steps
  void addTestSteps(int steps) {
    _dailySteps += steps;
    _stepsController.add(_dailySteps);
  }
  
  // Reset daily steps (call at midnight)
  void resetDailySteps() {
    _dailySteps = 0;
    _stepsController.add(_dailySteps);
  }
}

