import 'dart:async';
import 'dart:isolate';
import 'dart:math'; // Import dart:math for max()
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(StepTaskHandler());
}

class StepTaskHandler extends TaskHandler {
  StreamSubscription<StepCount>? _stepStream;
  int _steps = 0; // Raw pedometer reading
  int? _dailyStepOffset;
  int? _lastKnownDbSteps; // Variable to store baseline from DB

  // Battle state variables (from user's previous code)
  bool _isBattleActive = false;
  int _myScore = 0;
  int _opponentScore = 0;
  String _timeLeftString = '';

  final NotificationIcon notificationIcon =
      const NotificationIcon(metaDataName: '@drawable/ic_notification'); // Corrected Icon usage

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('StepTaskHandler started');

    int? loadedOffset;
    try {
      final prefs = await SharedPreferences.getInstance();
      loadedOffset = prefs.getInt('dailyStepOffset');
      print('StepTaskHandler loaded offset onStart: $loadedOffset');
    } catch (e) {
      print('StepTaskHandler ERROR reading offset onStart: $e. Treating as null.');
      loadedOffset = null;
    }
    _dailyStepOffset = loadedOffset;

    // --- Also try to load last known steps from service's own storage on start ---
    // This helps if the service restarts but the app hasn't sent the value yet
    try {
        final dynamic storedDbSteps = await FlutterForegroundTask.getData(key: 'lastKnownDbSteps');
        if (storedDbSteps is int) {
            _lastKnownDbSteps = storedDbSteps;
            print('StepTaskHandler loaded lastKnownDbSteps from service storage: $_lastKnownDbSteps');
        }
    } catch (e) {
        print('StepTaskHandler ERROR reading lastKnownDbSteps from service storage: $e.');
    }
    // --- End load ---


    _stepStream = Pedometer.stepCountStream.listen((event) {
      _steps = event.steps; // Update raw pedometer reading
      _updateAndSendData(); // Call the consolidated update method
    });
  }

  @override
  Future<void> onReceiveData(Object data) async {
    bool needsUpdate = false; // Flag to check if notification needs update
    if (data is Map<String, dynamic>) {
      if (data.containsKey('offset')) {
        _dailyStepOffset = data['offset'] as int?;
        print('StepTaskHandler received offset: $_dailyStepOffset');
        try {
          final prefs = await SharedPreferences.getInstance();
          if (_dailyStepOffset != null) {
            await prefs.setInt('dailyStepOffset', _dailyStepOffset!);
            print('StepTaskHandler successfully saved offset: $_dailyStepOffset');
          }
        } catch (e) {
          print('StepTaskHandler ERROR saving offset: $e.');
        }
        needsUpdate = true; // Need to recalculate steps with new offset
      }
      // --- Receive Baseline Steps from HomeScreen ---
      else if (data.containsKey('dbSteps')) {
        final newDbSteps = data['dbSteps'] as int?;
        // Update only if the new value is different
        if (_lastKnownDbSteps != newDbSteps) {
             _lastKnownDbSteps = newDbSteps;
             print('StepTaskHandler received dbSteps baseline: $_lastKnownDbSteps');
             // --- Save to service storage for persistence ---
             try {
                 if (_lastKnownDbSteps != null) {
                    await FlutterForegroundTask.saveData(key: 'lastKnownDbSteps', value: _lastKnownDbSteps!);
                    print('StepTaskHandler saved lastKnownDbSteps to service storage: $_lastKnownDbSteps');
                 } else {
                     await FlutterForegroundTask.removeData(key: 'lastKnownDbSteps');
                 }
             } catch (e) {
                 print('StepTaskHandler ERROR saving lastKnownDbSteps to service storage: $e.');
             }
             // --- End save ---
             needsUpdate = true; // Need to recalculate steps with new baseline
        }
      }
      // --- End Receive Baseline ---
       // --- Handle Battle Data (Copied from user's version) ---
      else if (data.containsKey('battleActive')) {
        _isBattleActive = data['battleActive'] ?? false;
        if (_isBattleActive) {
          _myScore = data['myScore'] ?? 0;
          _opponentScore = data['opponentScore'] ?? 0;
          _timeLeftString = data['timeLeft'] ?? '??:??';
          print('StepTaskHandler: Battle ACTIVE - Score $_myScore-$_opponentScore | Time $_timeLeftString');
        } else {
          print('StepTaskHandler: Battle INACTIVE');
        }
        needsUpdate = true; // Need to update notification text
      }
       // --- End Handle Battle Data ---

       // If any relevant data changed, trigger an update
       if (needsUpdate) {
            _updateAndSendData();
       }
    }
  }

  // --- Consolidated Calculation and Sending Logic ---
  void _updateAndSendData() {
    int stepsToShow = 0; // Default to 0

    if (_dailyStepOffset != null) {
      // Calculate steps based on offset
      int calculatedSteps = _steps - _dailyStepOffset!;
      if (calculatedSteps < 0) calculatedSteps = 0;

      // Determine steps to show using max with DB baseline
      // Use ?? 0 to safely handle null _lastKnownDbSteps initially
      stepsToShow = max(calculatedSteps, _lastKnownDbSteps ?? 0);

    } else {
       // Cannot calculate accurately without offset, maybe use baseline if available?
       // Or stick to 0 until offset arrives. Let's use baseline if known.
       stepsToShow = _lastKnownDbSteps ?? 0;
       print("StepTaskHandler: Offset is null, showing baseline steps: $stepsToShow");
    }

    _updateNotification(stepsToShow); // Update notification
    FlutterForegroundTask.sendDataToMain({'steps': stepsToShow}); // Send to UI
  }
  // --- End Consolidated Logic ---


  // Notification Update Logic (uses stepsToShow passed to it, includes battle state)
  void _updateNotification(int currentSteps) {
    String title;
    String body;

    if (_isBattleActive) {
      title = "⚔️ Ongoing Battle!";
      body = "You: $_myScore - Opponent: $_opponentScore | 🕒 $_timeLeftString"; // From user code
    } else {
      // Step counting notification logic (from user code)
      title = "🎯 StepWars Tracker";
      body = "Steps today: $currentSteps 👣";
      if (currentSteps > 10000) {
        title = "🏅 StepWars Elite!";
        body = "Boom! $currentSteps steps achieved! Time to rest those legs 😎";
      } else if (currentSteps > 5000) {
        title = "🚀 StepWars Rising Star!";
        body = "Awesome! $currentSteps steps done — halfway to glory 🌟";
      } else if (currentSteps > 1000) {
        title = "🌱 StepWars Starter";
        body = "Every legend starts small — $currentSteps steps so far 💪";
      }
    }

    FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: body,
      // notificationIcon: notificationIcon, // Ensure this is uncommented if needed
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
     // If using repeat event, ensure it calls _updateAndSendData()
     // _updateAndSendData();
  }


  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    print('StepTaskHandler destroyed');
    await _stepStream?.cancel();
    _stepStream = null;
  }

  // --- Other handlers remain the same ---
  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }
  @override
  void onNotificationButtonPressed(String id) { /* ... */ }
  @override
  void onNotificationDismissed() { /* ... */ }
}