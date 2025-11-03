import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(StepTaskHandler());
}

class StepTaskHandler extends TaskHandler {
  StreamSubscription<StepCount>? _stepStream;
  int _steps = 0;
  int? _dailyStepOffset;
  int? _lastKnownDbSteps;
  int? offsetTimestampMillis;
  String? _offsetDateString;
  bool _isBattleActive = false;
  int _myScore = 0;
  int _opponentScore = 0;
  String _timeLeftString = '';

  final NotificationIcon notificationIcon = const NotificationIcon(
      metaDataName: '@drawable/ic_notification'); // Corrected Icon usage

  String _getCurrentDateString() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<void> _initializePedometerStream() async {
    // If stream is already running, do nothing.
    if (_stepStream != null) return;

    var status = await Permission.activityRecognition.status;
    if (status.isGranted) {
      print("StepTaskHandler: Permission granted. Starting pedometer stream.");
      try {
        _stepStream = Pedometer.stepCountStream.listen((event) {
          _steps = event.steps;
          _updateAndSendData();
        }, onError: (e) {
          print("StepTaskHandler: Pedometer stream error: $e");
          FlutterForegroundTask.updateService(
            notificationTitle: 'Step Counter Error',
            notificationText: 'Pedometer stream failed.',
          );
          _stepStream?.cancel();
          _stepStream = null;
        });
      } catch (e) {
        print("StepTaskHandler: Error creating pedometer stream: $e");
      }
    } else {
      // Permission is not granted, update notification to inform user.
      print(
          "StepTaskHandler: Activity permission not granted. Stream not started.");
      FlutterForegroundTask.updateService(
        notificationTitle: 'Permission Needed',
        notificationText: 'Tap to open app and grant Activity permission.',
      );
    }
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('StepTaskHandler started');

    int? loadedOffset;
    try {
      final prefs = await SharedPreferences.getInstance();
      loadedOffset = prefs.getInt('dailyStepOffset');
      offsetTimestampMillis = prefs.getInt('dailyOffsetTimestamp');
      print('StepTaskHandler loaded offset onStart: $loadedOffset');
    } catch (e) {
      print(
          'StepTaskHandler ERROR reading offset onStart: $e. Treating as null.');
      loadedOffset = null;
      offsetTimestampMillis = null;
    }
    _dailyStepOffset = loadedOffset;
    if (offsetTimestampMillis != null) {
      _offsetDateString = DateFormat('yyyy-MM-dd')
          .format(DateTime.fromMillisecondsSinceEpoch(offsetTimestampMillis!));
    } else {
      _offsetDateString = _getCurrentDateString();
    }
    print('StepTaskHandler: Offset date initialized to: $_offsetDateString');
    try {
      final dynamic storedDbSteps =
          await FlutterForegroundTask.getData(key: 'lastKnownDbSteps');
      if (storedDbSteps is int) {
        _lastKnownDbSteps = storedDbSteps;
        print(
            'StepTaskHandler loaded lastKnownDbSteps from service storage: $_lastKnownDbSteps');
      }
    } catch (e) {
      print(
          'StepTaskHandler ERROR reading lastKnownDbSteps from service storage: $e.');
    }

    await _initializePedometerStream();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_stepStream == null) {
      print("StepTaskHandler [onRepeatEvent]: Stream is null, attempting to re-initialize.");
      _initializePedometerStream();
    }
    final String todayString = _getCurrentDateString();
    if (_offsetDateString != null && _offsetDateString != todayString) {
      print(
          'StepTaskHandler [onRepeatEvent]: New day detected! (Was $_offsetDateString, now $todayString)');
      print(
          'StepTaskHandler: Invalidating old offset. Waiting for app to provide new one.');
      _dailyStepOffset = null;
      _lastKnownDbSteps = 0;
      _offsetDateString = todayString;
      _updateNotificationAndData();
    }
  }

  @override
  Future<void> onReceiveData(Object data) async {
    bool needsUpdate = false;
    if (data is Map<String, dynamic>) {
      if (data.containsKey('offset')) {
        _dailyStepOffset = data['offset'] as int?;
        print('StepTaskHandler received offset: $_dailyStepOffset');
        _offsetDateString = _getCurrentDateString();
        print(
            'StepTaskHandler: Offset date updated to $_offsetDateString via onReceiveData');
        try {
          final prefs = await SharedPreferences.getInstance();
          if (_dailyStepOffset != null) {
            await prefs.setInt(
                'dailyOffsetTimestamp', DateTime.now().millisecondsSinceEpoch);
            print(
                'StepTaskHandler successfully saved offset: $_dailyStepOffset');
          }
        } catch (e) {
          print('StepTaskHandler ERROR saving offset: $e.');
        }
        needsUpdate = true; // Need to recalculate steps with new offset
      } else if (data.containsKey('dbSteps')) {
        final newDbSteps = data['dbSteps'] as int?;
        if (_lastKnownDbSteps != newDbSteps) {
          _lastKnownDbSteps = newDbSteps;
          print(
              'StepTaskHandler received dbSteps baseline: $_lastKnownDbSteps');
          try {
            if (_lastKnownDbSteps != null) {
              await FlutterForegroundTask.saveData(
                  key: 'lastKnownDbSteps', value: _lastKnownDbSteps!);
              print(
                  'StepTaskHandler saved lastKnownDbSteps to service storage: $_lastKnownDbSteps');
            } else {
              await FlutterForegroundTask.removeData(key: 'lastKnownDbSteps');
            }
          } catch (e) {
            print(
                'StepTaskHandler ERROR saving lastKnownDbSteps to service storage: $e.');
          }
          needsUpdate = true; // Need to recalculate steps with new baseline
        }
      } else if (data.containsKey('battleActive')) {
        _isBattleActive = data['battleActive'] ?? false;
        if (_isBattleActive) {
          _myScore = data['myScore'] ?? 0;
          _opponentScore = data['opponentScore'] ?? 0;
          _timeLeftString = data['timeLeft'] ?? '??:??';
          print(
              'StepTaskHandler: Battle ACTIVE - Score $_myScore-$_opponentScore | Time $_timeLeftString');
        } else {
          print('StepTaskHandler: Battle INACTIVE');
        }
        needsUpdate = true;
      }
      if (needsUpdate) {
        _updateAndSendData();
      }
    }
  }

  int _calculateStepsToShow() {
    int stepsToShow = 0;
    if (_dailyStepOffset == null) {
      print(
          "StepTaskHandler: Offset is NULL (new day?). Reporting baseline steps: ${_lastKnownDbSteps ?? 0}");
      stepsToShow = _lastKnownDbSteps ?? 0;
    } else {
      int calculatedSteps = _steps - _dailyStepOffset!;
      if (calculatedSteps < 0) calculatedSteps = 0;
      stepsToShow = max(calculatedSteps, _lastKnownDbSteps ?? 0);
    }
    return stepsToShow;
  }

  void _updateAndSendData() {
    int stepsToShow = 0; // Default to 0

    if (_dailyStepOffset != null) {
      int calculatedSteps = _steps - _dailyStepOffset!;
      if (calculatedSteps < 0) calculatedSteps = 0;
      stepsToShow = max(calculatedSteps, _lastKnownDbSteps ?? 0);
    } else {
      stepsToShow = _lastKnownDbSteps ?? 0;
      print(
          "StepTaskHandler: Offset is null, showing baseline steps: $stepsToShow");
    }

    _updateNotificationAndData();
    FlutterForegroundTask.sendDataToMain({'steps': stepsToShow});
  }

  void _updateNotificationAndData() {
    int stepsToShow = _calculateStepsToShow();
    String title;
    String body;
    if (_isBattleActive) {
      title = "⚔️ Ongoing Battle!";
      body = "You: $_myScore - Opponent: $_opponentScore | 🕒 $_timeLeftString";
    } else {
      // Use the fancy titles from your previous code
      title = "🎯 StepWars Tracker";
      body = "Steps today: $stepsToShow 👣";
      if (stepsToShow > 10000) {
        title = "🏅 StepWars Elite!";
        body = "Boom! $stepsToShow steps achieved! Time to rest those legs 😎";
      } else if (stepsToShow > 5000) {
        title = "🚀 StepWars Rising Star!";
        body = "Awesome! $stepsToShow steps done — halfway to glory 🌟";
      }
    }

    FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: body,
      // notificationIcon: notificationIcon,
    );

    FlutterForegroundTask.sendDataToMain({'steps': stepsToShow});
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    print('StepTaskHandler destroyed');
    await _stepStream?.cancel();
    _stepStream = null;
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationButtonPressed(String id) {/* ... */}
  @override
  void onNotificationDismissed() {/* ... */}
}
