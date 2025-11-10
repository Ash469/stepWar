import 'dart:async';
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
  int _lastSavedPedometerReading = 0;
  bool _deviceWasRebooted = false;

  final NotificationIcon notificationIcon = const NotificationIcon(
      metaDataName: '@drawable/ic_notification');

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
          
          // ROBUST REBOOT DETECTION: Check if pedometer reading dropped significantly
          if (_lastSavedPedometerReading > 10 && _steps < _lastSavedPedometerReading && 
              (_lastSavedPedometerReading - _steps) > 10) {
            _deviceWasRebooted = true;
            print('🔄 StepTaskHandler: REBOOT DETECTED! LastSaved=' + _lastSavedPedometerReading.toString() + ', Current=' + _steps.toString());
            
            // Immediately recompute offset using DB baseline
            final int baseline = _lastKnownDbSteps ?? 0;
            final int newOffset = _steps - baseline;
            _dailyStepOffset = newOffset;
            _offsetDateString = _getCurrentDateString();
            
            SharedPreferences.getInstance().then((prefs) async {
              await prefs.setInt('dailyStepOffset', newOffset);
              await prefs.setInt('dailyOffsetTimestamp', DateTime.now().millisecondsSinceEpoch);
              await prefs.setInt('lastPedometerReading', _steps);
              print('✅ StepTaskHandler: REBOOT FIX APPLIED! NewOffset=' + newOffset.toString() + ' (baseline=' + baseline.toString() + ')');
            }).catchError((e) {
              print('StepTaskHandler ERROR saving reboot offset: ' + e.toString());
            });
            
            _deviceWasRebooted = false;
          }
          
          // Auto-compute offset on first event if missing
          if (_dailyStepOffset == null) {
            final int baseline = _lastKnownDbSteps ?? 0;
            final String todayString = _getCurrentDateString();
            final int newOffset = _steps - baseline;
            _dailyStepOffset = newOffset;
            _offsetDateString = todayString;
            SharedPreferences.getInstance().then((prefs) async {
              await prefs.setInt('dailyStepOffset', newOffset);
              await prefs.setInt('dailyOffsetTimestamp', DateTime.now().millisecondsSinceEpoch);
              await prefs.setInt('lastPedometerReading', _steps);
              print('StepTaskHandler: First pedometer event. Computed offset=' + newOffset.toString() + ' using baseline=' + baseline.toString());
            }).catchError((e) {
              print('StepTaskHandler ERROR saving first offset: ' + e.toString());
            });
          }
          
          // Continuously save pedometer reading for reboot detection
          _lastSavedPedometerReading = _steps;
          
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
    int? lastSavedReading;
    try {
      final prefs = await SharedPreferences.getInstance();
      loadedOffset = prefs.getInt('dailyStepOffset');
      offsetTimestampMillis = prefs.getInt('dailyOffsetTimestamp');
      lastSavedReading = prefs.getInt('lastPedometerReading');
      print('StepTaskHandler loaded offset onStart: $loadedOffset');
      print('StepTaskHandler loaded lastPedometerReading: $lastSavedReading');
    } catch (e) {
      print(
          'StepTaskHandler ERROR reading offset onStart: $e. Treating as null.');
      loadedOffset = null;
      offsetTimestampMillis = null;
      lastSavedReading = null;
    }
    _dailyStepOffset = loadedOffset;
    _lastSavedPedometerReading = lastSavedReading ?? 0;
    
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
    
    // Save pedometer reading periodically for reboot detection
    if (_steps > 0) {
      SharedPreferences.getInstance().then((prefs) async {
        await prefs.setInt('lastPedometerReading', _steps);
      }).catchError((_) {});
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

    // Legacy fallback: Detect mid-day pedometer reset if reboot wasn't caught
    if (_dailyStepOffset != null && _steps >= 0 && _steps < _dailyStepOffset!) {
      final int baseline = _lastKnownDbSteps ?? 0;
      final int diff = _dailyStepOffset! - _steps;
      if (diff > 10) {
        print('StepTaskHandler [onRepeatEvent]: Pedometer reset detected (steps=' + _steps.toString() + ' < offset=' + _dailyStepOffset.toString() + '). Recomputing offset using baseline=' + baseline.toString());
        final int newOffset = _steps - baseline;
        _dailyStepOffset = newOffset;
        _offsetDateString = todayString;
        SharedPreferences.getInstance().then((prefs) async {
          await prefs.setInt('dailyStepOffset', newOffset);
          await prefs.setInt('dailyOffsetTimestamp', DateTime.now().millisecondsSinceEpoch);
          await prefs.setInt('lastPedometerReading', _steps);
          print('StepTaskHandler: Persisted new offset=' + newOffset.toString() + ' after reboot.');
        }).catchError((e) {
          print('StepTaskHandler ERROR persisting new offset after reboot: ' + e.toString());
        });
        _updateAndSendData();
      }
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

          // REMOVED: Offset realignment logic to prevent drastic step drops
          // Offset should only be recalculated on new day or explicit reboot detection
          // NOT on every dbSteps update to avoid race conditions and incorrect calculations

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
