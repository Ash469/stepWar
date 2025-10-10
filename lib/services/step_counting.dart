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

  Future<bool> _requestPermission() async {
    var status = await Permission.activityRecognition.status;
    if (status.isDenied) {
      status = await Permission.activityRecognition.request();
    }
    // You can add more detailed permission handling here if needed
    return status.isGranted;
  }

  Future<void> initialize() async {
    _stepCountSubscription?.cancel();
    final hasPermission = await _requestPermission();
    if (!hasPermission) {
      _stepController.addError('Permission denied.');
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
        cancelOnError: true,
      );
    } catch (error) {
      _stepController.addError('Pedometer not available on this device.');
    }
  }

  void dispose() {
    _stepCountSubscription?.cancel();
    _stepController.close();
  }
}
