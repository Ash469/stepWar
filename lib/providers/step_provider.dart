import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/google_fit_service.dart';
import '../services/step_history_service.dart';
import '../models/step_stats_model.dart';

/// Single Source of Truth for Step Counting
///
/// This provider manages all step-related state and logic.
/// Both HomeScreen and ProfileScreen watch this provider for updates.
class StepProvider extends ChangeNotifier {
  int _currentSteps = 0;
  int _dbSteps = 0;
  bool _isInitialized = false;
  bool _offsetInitializationDone = false;

  // Google Fit integration
  final GoogleFitService _googleFitService = GoogleFitService();
  final StepHistoryService _stepHistoryService = StepHistoryService();
  bool _isGoogleFitEnabled = false;
  bool _isGoogleFitInitialized = false;
  DateTime? _lastGoogleFitSync;

  // Weekly and monthly stats
  WeeklyStepStats? _weeklyStats;
  MonthlyStepStats? _monthlyStats;
  int _weeklySteps = 0;
  int _monthlySteps = 0;

  int get currentSteps => _currentSteps;
  int get dbSteps => _dbSteps;
  bool get isInitialized => _isInitialized;
  bool get isGoogleFitEnabled => _isGoogleFitEnabled;
  DateTime? get lastGoogleFitSync => _lastGoogleFitSync;
  WeeklyStepStats? get weeklyStats => _weeklyStats;
  MonthlyStepStats? get monthlyStats => _monthlyStats;
  int get weeklySteps => _weeklySteps;
  int get monthlySteps => _monthlySteps;

  StepProvider() {
    _initializeSync();
    _initializeGoogleFit();
  }

  void _initializeSync() {
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    _stepHistoryService.loadHistory();
    _loadInitialStepsSync();
    _isInitialized = true;
    notifyListeners();
  }

  /// it prevents the "Flash of Zero" when you first open the app.
  /// Instead of waiting for backend or a "heavy" library to initialize, it grabs the most recent step count from a local cache.
  void _loadInitialStepsSync() {
    try {
      SharedPreferences.getInstance().then((prefs) {
        final cachedProfile = prefs.getString('userProfile');
        if (cachedProfile != null) {
          // Parse the cached user profile to get today's step count
          final profileData = cachedProfile;
          final match =
              RegExp(r'"todaysStepCount"\s*:\s*(\d+)').firstMatch(profileData);
          if (match != null) {
            final steps = int.tryParse(match.group(1) ?? '0') ?? 0;
            _dbSteps = steps;
            _currentSteps = steps;
            print('[StepProvider] Initialized from cache: $steps steps');
            notifyListeners(); // this makes every screen to latest steps count
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
        if (_currentSteps != stepsFromService) {
          print(
              '[StepProvider] Received steps from service: $stepsFromService (previous: $_currentSteps)');
          _currentSteps = stepsFromService;
          notifyListeners();
        }
        // Handle stuck detection (similar to HomeScreen logic)
        if (_offsetInitializationDone && stepsFromService == _dbSteps) {
          print('[StepProvider] Stuck detection triggered');
        }
      }
    }
  }

  /// Send database steps to the foreground service
  void sendDbStepsToService(int steps) {
    print('[StepProvider] Sending DB steps ($steps) to service');
    FlutterForegroundTask.sendDataToTask({'dbSteps': steps});
    updateDbSteps(steps);
  }

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

  void markOffsetInitialized() {
    _offsetInitializationDone = true;
  }

  void resetOffsetInitialization() {
    _offsetInitializationDone = false;
  }

  void refresh() {
    _loadInitialStepsSync();
    _recoverFromHistory();
    if (_isGoogleFitEnabled) {
      syncWithGoogleFit();
    }
  }

  Future<void> _recoverFromHistory() async {
    try {
      if (_currentSteps == 0) {
        final recoveredSteps = await _stepHistoryService.recoverTodaySteps();
        if (recoveredSteps != null && recoveredSteps > 0) {
          print('[StepProvider] Recovered $recoveredSteps steps from history');
          _currentSteps = recoveredSteps;
          notifyListeners();
        }
      }
    } catch (e) {
      print('[StepProvider] Error recovering from history: $e');
    }
  }

  Map<String, int> getStepHistory(int days) {
    return _stepHistoryService.getLastNDays(days);
  }

  // ========== Google Fit Integration Methods ==========
  //these are permission handling methods should not be here
  HealthConnectStatus _connectionStatus = HealthConnectStatus.notAuthorized;
  HealthConnectStatus get connectionStatus => _connectionStatus;

  /// Initialize Google Fit service
  Future<void> _initializeGoogleFit() async {
    try {
      final enabled = await _googleFitService.isEnabled();
      if (enabled) {
        final initialized = await _googleFitService.initialize();
        if (initialized) {
          _connectionStatus =
              await _googleFitService.checkHealthConnectStatus();
          if (_connectionStatus == HealthConnectStatus.authorized) {
            _isGoogleFitEnabled = true;
            _isGoogleFitInitialized = true;
            print('[StepProvider] Google Fit initialized and enabled');
            syncWithGoogleFit();
          }
        }
      }
    } catch (e) {
      print('[StepProvider] Error initializing Google Fit: $e');
    }
    notifyListeners();
  }

  /// Request Google Fit authorization
  Future<HealthConnectStatus> requestGoogleFitAuthorization() async {
    try {
      var status = await _googleFitService.checkHealthConnectStatus();
      _connectionStatus = status;
      if (status == HealthConnectStatus.notInstalled) {
        await _googleFitService.installHealthConnect();
        return status;
      }
      if (status == HealthConnectStatus.authorized) {
        _enableAndSync();
        return status;
      }
      await _googleFitService.requestAuthorization();
      status = await _googleFitService.checkHealthConnectStatus();
      _connectionStatus = status;
      if (status == HealthConnectStatus.authorized) {
        _enableAndSync();
      }
      notifyListeners();
      return status;
    } catch (e) {
      print('[StepProvider] Error requesting Google Fit authorization: $e');
      return HealthConnectStatus.notSupported;
    }
  }

  void _enableAndSync() {
    _isGoogleFitEnabled = true;
    _isGoogleFitInitialized = true;
    notifyListeners();
    syncWithGoogleFit();
  }

  /// Sync current steps with Google Fit
  Future<void> syncWithGoogleFit() async {
    if (!_isGoogleFitEnabled || !_isGoogleFitInitialized) {
      return;
    }
    try {
      final googleFitSteps = await _googleFitService.getTodaySteps();
      if (googleFitSteps > 0) {
        print(
            '[StepProvider] Google Fit steps: $googleFitSteps, Current steps: $_currentSteps');
        if (googleFitSteps > _currentSteps) {
          _currentSteps = googleFitSteps;
          print(
              '[StepProvider] Updated steps from Google Fit: $googleFitSteps');
          notifyListeners();
        }
      }
      _lastGoogleFitSync = DateTime.now();
      notifyListeners();
    } catch (e) {
      print('[StepProvider] Error syncing with Google Fit: $e');
    }
  }

  /// Sync weekly steps from Google Fit
  Future<void> syncWeeklySteps() async {
    if (!_isGoogleFitEnabled || !_isGoogleFitInitialized) {
      print(
          '[StepProvider] Cannot sync weekly steps - Google Fit not enabled/initialized');
      return;
    }
    try {
      final weeklyStepsMap = await _googleFitService.getWeeklySteps();
      print(
          '[StepProvider] Weekly steps map received: ${weeklyStepsMap.length} days');
      if (weeklyStepsMap.isEmpty) {
        print('[StepProvider] WARNING: Weekly steps map is empty!');
      } else {
        weeklyStepsMap.forEach((date, steps) {
          print(
              '[StepProvider] Weekly data - ${date.toIso8601String().split('T')[0]}: $steps steps');
        });
      }
      _weeklyStats = WeeklyStepStats.fromStepsMap(weeklyStepsMap);
      _weeklySteps = _weeklyStats?.totalSteps ?? 0;
      print(
          '[StepProvider] Weekly stats synced: $_weeklySteps total steps, ${_weeklyStats?.dailyData.length ?? 0} days');
      notifyListeners();
    } catch (e) {
      print('[StepProvider] Error syncing weekly steps: $e');
      print('[StepProvider] Stack trace: ${StackTrace.current}');
    }
  }

  /// Sync monthly steps from Google Fit
  Future<void> syncMonthlySteps() async {
    if (!_isGoogleFitEnabled || !_isGoogleFitInitialized) {
      print(
          '[StepProvider] Cannot sync monthly steps - Google Fit not enabled/initialized');
      return;
    }
    try {
      final monthlyStepsMap = await _googleFitService.getMonthlySteps();
      print(
          '[StepProvider] Monthly steps map received: ${monthlyStepsMap.length} days');
      if (monthlyStepsMap.isEmpty) {
        print('[StepProvider] WARNING: Monthly steps map is empty!');
      }
      _monthlyStats = MonthlyStepStats.fromStepsMap(monthlyStepsMap);
      _monthlySteps = _monthlyStats?.totalSteps ?? 0;
      print(
          '[StepProvider] Monthly stats synced: $_monthlySteps total steps, ${_monthlyStats?.dailyData.length ?? 0} days');
      notifyListeners();
    } catch (e) {
      print('[StepProvider] Error syncing monthly steps: $e');
      print('[StepProvider] Stack trace: ${StackTrace.current}');
    }
  }

  /// Sync all Google Fit data (daily, weekly, monthly)
  Future<void> syncAllGoogleFitData() async {
    if (!_isGoogleFitEnabled || !_isGoogleFitInitialized) {
      return;
    }
    await Future.wait([
      syncWithGoogleFit(),
      syncWeeklySteps(),
      syncMonthlySteps(),
    ]);
  }

  /// Disable Google Fit integration
  /// this is done just to that user can disable google fit but never used
  Future<void> disableGoogleFit() async {
    await _googleFitService.disable();
    _isGoogleFitEnabled = false;
    _weeklyStats = null;
    _monthlyStats = null;
    _weeklySteps = 0;
    _monthlySteps = 0;
    _lastGoogleFitSync = null;
    notifyListeners();
    print('[StepProvider] Google Fit disabled');
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    super.dispose();
  }
}
