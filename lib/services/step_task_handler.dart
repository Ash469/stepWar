import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'google_fit_service.dart';

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
  String? _localStepCountDate; // Date of the local step count (yyyy-MM-dd)
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
  DateTime _lastGoogleFitSync =
      DateTime.now().subtract(const Duration(minutes: 20));
  final GoogleFitService _googleFitService = GoogleFitService();
  bool _googleFitEnabled = false;

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
            // 🔑 Use LOCAL step count as baseline if available, otherwise use DB steps
            final int baseline = _localStepCount ?? _lastKnownDbSteps ?? 0;
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
                  ', localStepCount=' +
                  (_localStepCount?.toString() ?? 'null') +
                  ')');
            }).catchError((e) {
              print('StepTaskHandler ERROR saving reboot offset: ' +
                  e.toString());
            });
          }

          // Auto-compute offset on first event if missing
          if (_dailyStepOffset == null) {
            // 🔑 Use LOCAL step count as baseline if available, otherwise use DB steps
            final int baseline = _localStepCount ?? _lastKnownDbSteps ?? 0;
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
                  baseline.toString() +
                  ' (localStepCount=' +
                  (_localStepCount?.toString() ?? 'null') +
                  ')');
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
      _localStepCountDate = prefs.getString('local_step_count_date');

      // 🔑 VALIDATE LOCAL STEP COUNT DATE - Only clear if from PREVIOUS day
      final today = _getCurrentDateString();
      if (_localStepCountDate != null && _localStepCountDate != today) {
        // Check if it's actually from a previous day (not just missing date)
        try {
          final localDate = DateTime.parse(_localStepCountDate!);
          final todayDate = DateTime.parse(today);

          if (localDate.isBefore(todayDate)) {
            print(
                '🗓️ StepTaskHandler: Local step count is from PREVIOUS day $_localStepCountDate, clearing it. Today is $today.');
            await prefs.remove('local_step_count');
            await prefs.remove('local_step_count_date');
            _localStepCount = null;
            _localStepCountDate = null;
          } else if (localDate.isAfter(todayDate)) {
            // Future date - user changed device time backwards
            print(
                '⚠️ StepTaskHandler: Local step count is from FUTURE date $_localStepCountDate, clearing it. Today is $today.');
            await prefs.remove('local_step_count');
            await prefs.remove('local_step_count_date');
            _localStepCount = null;
            _localStepCountDate = null;
          } else {
            print(
                '🗓️ StepTaskHandler: Local step count date $_localStepCountDate is valid (same day).');
          }
        } catch (e) {
          print(
              'StepTaskHandler: Error parsing dates: $e. Keeping local count since we cannot confirm it is outdated.');
          // Don't clear - we can't confirm the date is wrong
        }
      } else if (_localStepCountDate == null && _localStepCount != null) {
        // No date stored but we have a count - assume it's from today and add the date
        print(
            '🔑 StepTaskHandler: Local step count has no date, assuming today and adding date.');
        await prefs.setString('local_step_count_date', today);
        _localStepCountDate = today;
      }

      print('StepTaskHandler loaded offset onStart: $loadedOffset');
      print('StepTaskHandler loaded lastPedometerReading: $lastSavedReading');
      print(
          '🔑 StepTaskHandler loaded LOCAL step count: $_localStepCount (date: $_localStepCountDate)');
    } catch (e) {
      print(
          'StepTaskHandler ERROR reading offset onStart: $e. Treating as null.');
      loadedOffset = null;
      offsetTimestampMillis = null;
      lastSavedReading = null;
      _localStepCount = null;
      _localStepCountDate = null;
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
    await _initializeGoogleFit();
  }

  /// Initialize Google Fit for background sync
  Future<void> _initializeGoogleFit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _googleFitEnabled = prefs.getBool('google_fit_enabled') ?? false;

      if (_googleFitEnabled) {
        final initialized = await _googleFitService.initialize();
        if (initialized) {
          final hasPerms = await _googleFitService.hasPermissions();
          if (hasPerms) {
            print(
                '[StepTaskHandler] Google Fit initialized for background sync');
          } else {
            _googleFitEnabled = false;
          }
        }
      }
    } catch (e) {
      print('[StepTaskHandler] Error initializing Google Fit: $e');
      _googleFitEnabled = false;
    }
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

        // 🔑 CLEAR LOCAL STEP COUNT ON NEW DAY
        prefs.remove('local_step_count');
        prefs.remove('local_step_count_date');
        print("🗓️ [StepTaskHandler] Cleared local step count for new day");

        _dailyStepOffset = newOffset;
        _lastKnownDbSteps = 0;
        _localStepCount = null;
        _localStepCountDate = null;
        _offsetDateString = todayString;
        _updateAndSendData();
      });
    }
    _attemptBackgroundSync();
    _attemptGoogleFitSync();
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

  /// Attempt to sync with Google Fit (every 15 minutes)
  Future<void> _attemptGoogleFitSync() async {
    if (!_googleFitEnabled) return;

    final now = DateTime.now();
    if (now.difference(_lastGoogleFitSync).inMinutes >= 15) {
      try {
        // Get today's steps from Google Fit
        final googleFitSteps = await _googleFitService.getTodaySteps();

        if (googleFitSteps > 0) {
          final currentSteps = _calculateStepsToShow();

          // If Google Fit has more steps, update our local count
          if (googleFitSteps > currentSteps) {
            print(
                '[StepTaskHandler] Google Fit sync: $googleFitSteps steps (current: $currentSteps)');

            // Update local step count
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('local_step_count', googleFitSteps);
            _localStepCount = googleFitSteps;

            // Trigger UI update
            _updateAndSendData();
          }
        }

        _lastGoogleFitSync = now;
      } catch (e) {
        print('[StepTaskHandler] Error syncing with Google Fit: $e');
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

        // 🔑 LOCAL STORAGE IS SOURCE OF TRUTH - Only accept DB steps if higher AND from today
        final today = _getCurrentDateString();

        // First, validate that local count is from today
        if (_localStepCount != null && _localStepCountDate != today) {
          print(
              '⚠️ StepTaskHandler: Local step count date ($_localStepCountDate) != today ($today). Clearing outdated local count.');
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('local_step_count');
          await prefs.remove('local_step_count_date');
          _localStepCount = null;
          _localStepCountDate = null;
        }

        // Now check if we should ignore DB steps
        if (_localStepCount != null &&
            _localStepCountDate == today &&
            newDbSteps != null &&
            newDbSteps <= _localStepCount!) {
          print(
              '🔑 StepTaskHandler: IGNORING dbSteps ($newDbSteps) - Local step count ($_localStepCount) from today is SOURCE OF TRUTH');
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
    // 🔑 OPTION A: Always use raw calculated pedometer value
    // This value updates continuously with every step

    if (_dailyStepOffset == null) {
      // No offset yet (app just started, waiting for first pedometer event)
      // Return 0 until we get pedometer data
      print(
          "StepTaskHandler: Offset is NULL (waiting for pedometer). Showing: 0");
      return 0;
    }

    int calculatedSteps = _steps - _dailyStepOffset!;
    if (calculatedSteps < 0) {
      calculatedSteps = 0;
    }

    print(
        "🔢 StepTaskHandler: Raw pedometer value: $_steps - $_dailyStepOffset = $calculatedSteps steps");
    return calculatedSteps;
  }

  void _updateAndSendData() async {
    int stepsToShow = _calculateStepsToShow();

    // 🔑 SAVE LOCAL STEP COUNT - This is the source of truth
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getCurrentDateString();
      await prefs.setInt('local_step_count', stepsToShow);
      await prefs.setString('local_step_count_date', today);
      _localStepCount = stepsToShow; // Update in-memory value
      _localStepCountDate = today; // Update in-memory date
      print(
          '🔑 StepTaskHandler: Saved LOCAL step count: $stepsToShow (date: $today)');
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
