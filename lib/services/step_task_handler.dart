import 'dart:async';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'step_history_service.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(StepTaskHandler());
}

class StepTaskHandler extends TaskHandler {
  StreamSubscription<StepCount>? _stepStream;
  int _steps = 0;
  int? _dailyStepOffset;
  int? _lastKnownDbSteps;
  int? _localStepCount;
  int? offsetTimestampMillis;
  String? _offsetDateString;
  bool _isBattleActive = false;
  int _myScore = 0;
  int _opponentScore = 0;
  String _timeLeftString = '';
  int _lastSavedPedometerReading = 0;

  final StepHistoryService _historyService = StepHistoryService();

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

          bool rebootDetected = false;
          // Condition 1: Steps dropped significantly vs last saved reading
          if (_lastSavedPedometerReading > 10 &&
              _steps < _lastSavedPedometerReading &&
              (_lastSavedPedometerReading - _steps) > 10) {
            rebootDetected = true;
          }
          // Condition 2: Steps are less than current offset (Mathematical impossibility in same session)
          if (_dailyStepOffset != null && _steps < _dailyStepOffset!) {
            print(
                "StepTaskHandler: Reboot Detected via Offset Check! Steps: $_steps < Offset: $_dailyStepOffset");
            rebootDetected = true;
          }

          int currentCalculated = _steps - (_dailyStepOffset ?? 0);
          if (_localStepCount != null &&
              currentCalculated < (_localStepCount! - 10)) {
            print(
                "StepTaskHandler: Reboot Detected via Local Count Check! Calculated: $currentCalculated < Local: $_localStepCount");
            rebootDetected = true;
          }

          if (rebootDetected) {
            print('🔄 StepTaskHandler: REBOOT DETECTED! LastSaved=' +
                _lastSavedPedometerReading.toString() +
                ', Current=' +
                _steps.toString());

            // 🔑 REBOOT RESUME: Use local step count as baseline if available and higher than DB
            int baseline = _lastKnownDbSteps ?? 0;
            if (_localStepCount != null && _localStepCount! > baseline) {
              baseline = _localStepCount!;
            }

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
            // 🔑 STARTUP/RESUME: Use local step count as baseline if available
            int baseline = _lastKnownDbSteps ?? 0;
            if (_localStepCount != null && _localStepCount! > baseline) {
              baseline = _localStepCount!;
            }

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
    // 📊 Load step history first
    await _historyService.loadHistory();
    int? loadedOffset;
    int? lastSavedReading;
    try {
      final prefs = await SharedPreferences.getInstance();
      loadedOffset = prefs.getInt('dailyStepOffset');
      offsetTimestampMillis = prefs.getInt('dailyOffsetTimestamp');
      lastSavedReading = prefs.getInt('lastPedometerReading');

      // 🔑 LOAD LOCAL STEP COUNT - THIS IS THE SOURCE OF TRUTH
      _localStepCount = prefs.getInt('local_step_count');
      final String? localStepCountDate =
          prefs.getString('local_step_count_date');
      final String todayString = _getCurrentDateString();

      // Validate that local step count is from today
      if (_localStepCount != null && localStepCountDate != null) {
        if (localStepCountDate != todayString) {
          print(
              '🔑 StepTaskHandler: Local step count is from $localStepCountDate, today is $todayString. Resetting to null.');
          _localStepCount = null;
          await prefs.remove('local_step_count');
          await prefs.remove('local_step_count_date');
        }
      } else if (_localStepCount != null && localStepCountDate == null) {
        print(
            '🔑 StepTaskHandler: Local step count has no date. Resetting to null.');
        _localStepCount = null;
        await prefs.remove('local_step_count');
      }
      if (_localStepCount == null) {
        final historicalSteps = _historyService.getStepsForDate(todayString);
        if (historicalSteps != null) {
          _localStepCount = historicalSteps;
          print(
              '📊 StepTaskHandler: Loaded historical steps for $todayString: $historicalSteps');
        }
      }
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
    _updateAndSendData();
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

      // 📊 Save yesterday's steps to history
      _historyService.saveStepsForDate(_offsetDateString!, finalStepsYesterday);

      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('pending_past_date', _offsetDateString!);
        prefs.setInt('pending_past_steps', finalStepsYesterday);
        print(
            "💾 [StepTaskHandler] Saved Snapshot: $finalStepsYesterday steps for $_offsetDateString");
        final int newOffset = _steps;
        prefs.setInt('dailyStepOffset', newOffset);
        prefs.setInt(
            'dailyOffsetTimestamp', DateTime.now().millisecondsSinceEpoch);
        prefs.remove('service_last_known_db_steps');

        prefs.remove('local_step_count');
        prefs.remove('local_step_count_date');
        _localStepCount = null;
        print("🔑 [StepTaskHandler] Reset local step count for new day");

        _dailyStepOffset = newOffset;
        _lastKnownDbSteps = 0;
        _offsetDateString = todayString;

        _historyService.cleanupOldEntries();

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
      _lastKnownDbSteps = steps;
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
        needsUpdate = true;
      } else if (data.containsKey('dbSteps')) {
        final newDbSteps = data['dbSteps'] as int?;

        if (_localStepCount != null &&
            newDbSteps != null &&
            newDbSteps <= _localStepCount!) {
          print(
              '🔑 StepTaskHandler: IGNORING dbSteps ($newDbSteps) - Local step count ($_localStepCount) is SOURCE OF TRUTH');
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

          needsUpdate = true;
        }
      } else if (data.containsKey('battleActive')) {
        bool newBattleActive = data['battleActive'] ?? false;
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
    if (_localStepCount != null && _dailyStepOffset != null) {
      int calculatedSteps = _steps - _dailyStepOffset!;
      if (calculatedSteps < 0) calculatedSteps = 0;
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
      final String todayString = _getCurrentDateString();

      // 📊 Check historical steps and use the higher value
      final existingHistoricalSteps =
          _historyService.getStepsForDate(todayString);
      final int stepsToSave = (existingHistoricalSteps != null &&
              existingHistoricalSteps > stepsToShow)
          ? existingHistoricalSteps
          : stepsToShow;

      await prefs.setInt('local_step_count', stepsToSave);
      await prefs.setString('local_step_count_date', todayString);
      _localStepCount = stepsToSave;

      // 📊 Save to step history only if higher than existing value
      if (existingHistoricalSteps == null ||
          stepsToSave > existingHistoricalSteps) {
        await _historyService.saveStepsForDate(todayString, stepsToSave);
      }

      print(
          '🔑 StepTaskHandler: Saved LOCAL step count: $stepsToSave for date: $todayString (calculated: $stepsToShow, historical: $existingHistoricalSteps)');
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
