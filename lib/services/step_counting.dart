import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';


class HealthService {
  late Stream<StepCount> _stepCountStream;
  StreamSubscription<StepCount>? _stepCountSubscription;
  final _stepController = StreamController<String>.broadcast();
  Stream<String> get stepStream => _stepController.stream;
  Future<bool> _requestPermission() async {
    var status = await Permission.activityRecognition.status;
    if (status.isDenied) {
      status = await Permission.activityRecognition.request();
    }

    if (status.isPermanentlyDenied) {
       _stepController.addError('Permission permanently denied. Please enable it from app settings.');
       openAppSettings();
       return false;
    }

    if (status.isGranted) {
      return true;
    } else {
      _stepController.addError('Permission denied. Step tracking will not work.');
      return false;
    }
  }
  Future<void> initialize() async {
    final hasPermission = await _requestPermission();
    if (!hasPermission) {
      print("Could not get activity recognition permission.");
      return;
    }

    try {
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountSubscription = _stepCountStream.listen(
        (StepCount event) {
          _stepController.add(event.steps.toString());
        },
        onError: (error) {
          print('Pedometer Error: $error');
          _stepController.addError('Step count not available');
        },
        cancelOnError: true,
      );
    } catch (error) {
      print("Error initializing Pedometer: $error");
       _stepController.addError('Pedometer not available on this device.');
    }
  }
  void dispose() {
    _stepCountSubscription?.cancel();
    _stepController.close();
  }
}

