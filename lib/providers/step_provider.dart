import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single Source of Truth for Step Counting
///
/// This provider manages all step-related state and logic.
/// Both HomeScreen and ProfileScreen watch this provider for updates.
class StepProvider extends ChangeNotifier {
  int _currentSteps = 0;
  int _dbSteps = 0;
  bool _isInitialized = false;
  bool _offsetInitializationDone = false;

  int get currentSteps => _currentSteps;
  int get dbSteps => _dbSteps;
  bool get isInitialized => _isInitialized;

  StepProvider() {
    _initializeSync();
  }

  /// Initialize the provider synchronously for faster startup
  void _initializeSync() {
    // Register callback to receive step updates from foreground service
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    // Load initial step count synchronously from cache
    _loadInitialStepsSync();

    _isInitialized = true;
    notifyListeners();
  }

  /// Load initial step count from SharedPreferences cache synchronously
  void _loadInitialStepsSync() {
    try {
      // SharedPreferences.getInstance() is cached after first call, so this is fast
      SharedPreferences.getInstance().then((prefs) {
        final cachedProfile = prefs.getString('userProfile');

        if (cachedProfile != null) {
          // Parse the cached user profile to get today's step count
          final profileData = cachedProfile;
          // Simple regex to extract todaysStepCount value
          final match =
              RegExp(r'"todaysStepCount"\s*:\s*(\d+)').firstMatch(profileData);
          if (match != null) {
            final steps = int.tryParse(match.group(1) ?? '0') ?? 0;
            _dbSteps = steps;
            _currentSteps = steps;
            print('[StepProvider] Initialized from cache: $steps steps');
            notifyListeners();
          }
        }
      });
    } catch (e) {
      print('[StepProvider] Error loading initial steps: $e');
    }
  }

  /// Callback that receives live step updates from the foreground service
  void _onReceiveTaskData(Object data) {
    if (data is Map<String, dynamic>) {
      if (data.containsKey('steps')) {
        final stepsFromService = data['steps'] as int;

        // Only update if value changed
        if (_currentSteps != stepsFromService) {
          print(
              '[StepProvider] Received steps from service: $stepsFromService (previous: $_currentSteps)');
          _currentSteps = stepsFromService;
          notifyListeners();
        }

        // Handle stuck detection (similar to HomeScreen logic)
        if (_offsetInitializationDone && stepsFromService == _dbSteps) {
          _handleStuckDetection();
        }
      }
    }
  }

  /// Handle case where steps appear stuck at database baseline
  void _handleStuckDetection() async {
    // This logic can be implemented if needed
    // For now, we'll keep it simple and let the foreground service handle it
    print('[StepProvider] Stuck detection triggered');
  }

  /// Update the database baseline when user profile is refreshed
  void updateDbSteps(int steps) {
    if (_dbSteps != steps) {
      print('[StepProvider] Updating DB steps: $_dbSteps -> $steps');
      _dbSteps = steps;

      // If current steps are lower than DB steps, update current steps
      if (_currentSteps < steps) {
        _currentSteps = steps;
      }

      notifyListeners();
    }
  }

  /// Send database steps to the foreground service
  void sendDbStepsToService(int steps) {
    print('[StepProvider] Sending DB steps ($steps) to service');
    FlutterForegroundTask.sendDataToTask({'dbSteps': steps});
    updateDbSteps(steps);
  }

  /// Mark offset initialization as complete
  void markOffsetInitialized() {
    _offsetInitializationDone = true;
  }

  /// Reset offset initialization flag (e.g., on new day)
  void resetOffsetInitialization() {
    _offsetInitializationDone = false;
  }

  /// Manually refresh steps (useful for pull-to-refresh)
  void refresh() {
    _loadInitialStepsSync();
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    super.dispose();
  }
}
