import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthService {
  HealthService._internal();
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;

  late Stream<StepCount> _stepCountStream;
  StreamSubscription<StepCount>? _stepCountSubscription;
  final _stepController = StreamController<String>.broadcast();
  Stream<String> get stepStream => _stepController.stream;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Check status, but DO NOT request.
    var status = await Permission.activityRecognition.status;
    if (!status.isGranted) {
      _stepController.addError('Permission needed.');
      return;
    }

    try {
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountSubscription = _stepCountStream.listen(
        (StepCount event) {
          _stepController.add(event.steps.toString());
        },
        onError: (error) {
          _stepController.addError('Step count not available');
        },
        cancelOnError: false,
      );
      _isInitialized = true;
    } catch (error) {
      _stepController.addError('Pedometer not available on this device.');
    }
  }

  void dispose() {
    _stepCountSubscription?.cancel();
    _stepCountSubscription = null;
    _isInitialized = false;
  }
}
