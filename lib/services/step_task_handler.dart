import 'dart:async';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(StepTaskHandler());
}

class StepTaskHandler extends TaskHandler {
  StreamSubscription<StepCount>? _stepStream;
  int _steps = 0;
  int? _dailyStepOffset;
  int? _lastKnownDbSteps;
  int? _localStepCount; // LOCAL STORAGE IS SOURCE OF TRUTH
  int? offsetTimestampMillis;
  String? _offsetDateString;
  bool _isBattleActive = false;
  int _myScore = 0;
  int _opponentScore = 0;
  String _timeLeftString = '';
  int _lastSavedPedometerReading = 0;

  // --- Sync Variables ---
  String? _userId;
  String? _backendUrl;
  DateTime _lastSyncTime = DateTime.now().subtract(const Duration(minutes: 20));
  String _getCurrentDateString() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  final NotificationIcon notificationIcon =
      const NotificationIcon(metaDataName: '@drawable/ic_notification');

  Future<void> _initializePedometerStream() async {
    if (_stepStream != null) return;

    var status = await Permission.activityRecognition.status;
    if (status.isGranted) {
      print("StepTaskHandler: Permission granted. Starting pedometer stream.");
      try {
        _stepStream = Pedometer.stepCountStream.listen((event) {
          _steps = event.steps;
          if (_lastSavedPedometerReading > 10 &&
              _steps < _lastSavedPedometerReading &&
              (_lastSavedPedometerReading - _steps) > 10) {
            print('🔄 StepTaskHandler: REBOOT DETECTED! LastSaved=' +
                _lastSavedPedometerReading.toString() +
                ', Current=' +
                _steps.toString());
            final int baseline = _lastKnownDbSteps ?? 0;
            final int newOffset = _steps - baseline;
            _dailyStepOffset = newOffset;
            _offsetDateString = _getCurrentDateString();

            SharedPreferences.getInstance().then((prefs) async {
              await prefs.setInt('dailyStepOffset', newOffset);
              await prefs.setInt('dailyOffsetTimestamp',
                  DateTime.now().millisecondsSinceEpoch);
              await prefs.setInt('lastPedometerReading', _steps);
              print('✅ StepTaskHandler: REBOOT FIX APPLIED! NewOffset=' +
                  newOffset.toString() +
                  ' (baseline=' +
                  baseline.toString() +
                  ')');
            }).catchError((e) {
              print('StepTaskHandler ERROR saving reboot offset: ' +
                  e.toString());
            });
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
              await prefs.setInt('dailyOffsetTimestamp',
                  DateTime.now().millisecondsSinceEpoch);
              await prefs.setInt('lastPedometerReading', _steps);
              print('StepTaskHandler: First pedometer event. Computed offset=' +
                  newOffset.toString() +
                  ' using baseline=' +
                  baseline.toString());
            }).catchError((e) {
              print(
                  'StepTaskHandler ERROR saving first offset: ' + e.toString());
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
    int? loadedOffset;
    int? lastSavedReading;
    try {
      final prefs = await SharedPreferences.getInstance();
      loadedOffset = prefs.getInt('dailyStepOffset');
      offsetTimestampMillis = prefs.getInt('dailyOffsetTimestamp');
      lastSavedReading = prefs.getInt('lastPedometerReading');

      // 🔑 LOAD LOCAL STEP COUNT - THIS IS THE SOURCE OF TRUTH
      _localStepCount = prefs.getInt('local_step_count');

      print('StepTaskHandler loaded offset onStart: $loadedOffset');
      print('StepTaskHandler loaded lastPedometerReading: $lastSavedReading');
      print(
          '🔑 StepTaskHandler loaded LOCAL step count: $_localStepCount (SOURCE OF TRUTH)');
    } catch (e) {
      print(
          'StepTaskHandler ERROR reading offset onStart: $e. Treating as null.');
      loadedOffset = null;
      offsetTimestampMillis = null;
      lastSavedReading = null;
      _localStepCount = null;
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
      final prefs = await SharedPreferences.getInstance();
      final int? storedDbSteps = prefs.getInt('service_last_known_db_steps');
      if (storedDbSteps != null) {
        _lastKnownDbSteps = storedDbSteps;
        print(
            'StepTaskHandler loaded lastKnownDbSteps from SharedPreferences: $_lastKnownDbSteps');
      }
    } catch (e) {
      print(
          'StepTaskHandler ERROR reading lastKnownDbSteps from SharedPreferences: $e.');
    }

    await _initializePedometerStream();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_stepStream == null) _initializePedometerStream();
    if (_steps > 0) {
      SharedPreferences.getInstance().then((prefs) async {
        await prefs.setInt('lastPedometerReading', _steps);
      }).catchError((_) {});
    }

    final String todayString = _getCurrentDateString();
    if (_offsetDateString != null && _offsetDateString != todayString) {
      print(
          "🌙 [StepTaskHandler] Midnight Detected! Switching from $_offsetDateString to $todayString");
      final int finalStepsYesterday = _calculateStepsToShow();
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('pending_past_date', _offsetDateString!);
        prefs.setInt('pending_past_steps', finalStepsYesterday);
        print(
            "💾 [StepTaskHandler] Saved Snapshot: $finalStepsYesterday steps for $_offsetDateString");
        final int newOffset = _steps;
        prefs.setInt('dailyStepOffset', newOffset);
        prefs.setInt(
            'dailyOffsetTimestamp', DateTime.now().millisecondsSinceEpoch);
        prefs.remove(
            'service_last_known_db_steps'); // Reset baseline for new day

        _dailyStepOffset = newOffset;
        _lastKnownDbSteps = 0;
        _offsetDateString = todayString;
        _updateAndSendData();
      });
    }
    _attemptBackgroundSync();
  }

  Future<void> _attemptBackgroundSync() async {
    if (_userId == null || _backendUrl == null) {
      _userId = await FlutterForegroundTask.getData(key: 'userId');
      _backendUrl = await FlutterForegroundTask.getData(key: 'backendUrl');
      if (_userId == null) return;
    }

    // 1. Check for Pending "Midnight Snapshots" first
    final prefs = await SharedPreferences.getInstance();
    final String? pendingDate = prefs.getString('pending_past_date');
    final int? pendingSteps = prefs.getInt('pending_past_steps');

    if (pendingDate != null && pendingSteps != null) {
      bool success = await _syncPastSteps(pendingDate, pendingSteps);
      if (success) {
        await prefs.remove('pending_past_date');
        await prefs.remove('pending_past_steps');
      }
    }

    // 2. Regular Sync (Every 15 minutes)
    final now = DateTime.now();
    if (now.difference(_lastSyncTime).inMinutes >= 15) {
      final int currentSteps = _calculateStepsToShow();
      if (currentSteps > 0 || _lastKnownDbSteps != 0) {
        await _syncCurrentSteps(currentSteps);
        _lastSyncTime = now;
      }
    }
  }

  Future<bool> _syncPastSteps(String date, int steps) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/api/user/sync-past-steps'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': _userId, 'date': date, 'steps': steps}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> _syncCurrentSteps(int steps) async {
    try {
      await http.post(
        Uri.parse('$_backendUrl/api/user/sync-steps'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': _userId, 'todaysStepCount': steps}),
      );
      _lastKnownDbSteps = steps; // Update local baseline
    } catch (e) {
      print("Error syncing current steps: $e");
    }
  }

  @override
  Future<void> onReceiveData(Object data) async {
    print("StepTaskHandler: onReceiveData called with data: $data");
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

        // 🔑 LOCAL STORAGE IS SOURCE OF TRUTH - Only accept DB steps if higher
        if (_localStepCount != null &&
            newDbSteps != null &&
            newDbSteps <= _localStepCount!) {
          print(
              '🔑 StepTaskHandler: IGNORING dbSteps ($newDbSteps) - Local step count ($_localStepCount) is SOURCE OF TRUTH');
          // Don't update, local storage takes precedence
        } else if (_lastKnownDbSteps != newDbSteps) {
          _lastKnownDbSteps = newDbSteps;
          print(
              'StepTaskHandler received dbSteps baseline: $_lastKnownDbSteps');
          try {
            final prefs = await SharedPreferences.getInstance();
            if (_lastKnownDbSteps != null) {
              await prefs.setInt(
                  'service_last_known_db_steps', _lastKnownDbSteps!);
              print(
                  'StepTaskHandler saved lastKnownDbSteps to SharedPreferences: $_lastKnownDbSteps');
            } else {
              await prefs.remove('service_last_known_db_steps');
            }
          } catch (e) {
            print(
                'StepTaskHandler ERROR saving lastKnownDbSteps to SharedPreferences: $e.');
          }

          needsUpdate = true; // Need to recalculate steps with new baseline
        }
      } else if (data.containsKey('battleActive')) {
        bool newBattleActive = data['battleActive'] ?? false;
        // Always update the battle state, even if it's the same value, to ensure scores are updated
        _isBattleActive = newBattleActive;
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

    // 🔑 If we have a local step count, use it as the baseline
    if (_localStepCount != null && _dailyStepOffset != null) {
      int calculatedSteps = _steps - _dailyStepOffset!;
      if (calculatedSteps < 0) calculatedSteps = 0;
      // Use the higher of calculated steps or local step count
      stepsToShow = max(calculatedSteps, _localStepCount!);
      print(
          "🔑 StepTaskHandler: Using LOCAL step count as baseline: $_localStepCount, calculated: $calculatedSteps, showing: $stepsToShow");
    } else if (_dailyStepOffset == null) {
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

  void _updateAndSendData() async {
    int stepsToShow = _calculateStepsToShow();

    // 🔑 SAVE LOCAL STEP COUNT - This is the source of truth
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('local_step_count', stepsToShow);
      _localStepCount = stepsToShow; // Update in-memory value
      print('🔑 StepTaskHandler: Saved LOCAL step count: $stepsToShow');
    } catch (e) {
      print('StepTaskHandler ERROR saving local step count: $e');
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
        body = "Boom! $stepsToShow steps achieved!😎";
      } else if (stepsToShow > 5000) {
        title = "🚀 StepWars Rising Star!";
        body = "Awesome! $stepsToShow steps done 🌟";
      }
    }

    // Create notification with action buttons
    final notificationButtons = <NotificationButton>[];

    // // Add cancel button only when not in battle
    // if (!_isBattleActive) {
    //   notificationButtons.add(
    //     NotificationButton(id: 'cancel', text: 'Cancel'),
    //   );
    // }

    FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: body,
      notificationButtons: notificationButtons,
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
