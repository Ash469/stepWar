import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to interact with Google Fit via Health Connect API
/// Handles step data fetching for daily, weekly, and monthly periods
class GoogleFitService {
  GoogleFitService._internal();
  static final GoogleFitService _instance = GoogleFitService._internal();
  factory GoogleFitService() => _instance;

  Health? _health;
  bool _isInitialized = false;
  bool _hasPermissions = false;

  static const String _lastSyncKey = 'google_fit_last_sync';
  static const String _enabledKey = 'google_fit_enabled';

  /// Initialize Health Connect API
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _health = Health();
      _isInitialized = true;
      print('[GoogleFitService] Initialized successfully');
      return true;
    } catch (e) {
      print('[GoogleFitService] Initialization error: $e');
      return false;
    }
  }

  /// Request authorization for step data
  Future<bool> requestAuthorization() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    try {
      // Define the types of health data we want to access
      final types = [
        HealthDataType.STEPS,
      ];

      // Request permissions
      final permissions = [
        HealthDataAccess.READ,
      ];

      final requested =
          await _health!.requestAuthorization(types, permissions: permissions);

      if (requested) {
        _hasPermissions = true;
        await _setEnabled(true);
        print('[GoogleFitService] Authorization granted');
      } else {
        print('[GoogleFitService] Authorization denied');
      }

      return requested;
    } catch (e) {
      print('[GoogleFitService] Authorization error: $e');
      return false;
    }
  }

  /// Check if we have permissions
  Future<bool> hasPermissions() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final types = [HealthDataType.STEPS];
      final permissions = await _health!.hasPermissions(types);
      _hasPermissions = permissions ?? false;
      return _hasPermissions;
    } catch (e) {
      print('[GoogleFitService] Permission check error: $e');
      return false;
    }
  }

  /// Get steps for today
  Future<int> getTodaySteps() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return await getStepsForDate(startOfDay);
  }

  /// Get steps for a specific date
  Future<int> getStepsForDate(DateTime date) async {
    if (!_hasPermissions) {
      final hasPerms = await hasPermissions();
      if (!hasPerms) {
        print('[GoogleFitService] No permissions to read steps');
        return 0;
      }
    }

    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final healthData = await _health!.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: startOfDay,
        endTime: endOfDay,
      );

      // Sum up all step counts for the day
      int totalSteps = 0;
      for (var data in healthData) {
        if (data.type == HealthDataType.STEPS) {
          totalSteps += (data.value as num).toInt();
        }
      }

      print(
          '[GoogleFitService] Steps for ${date.toIso8601String().split('T')[0]}: $totalSteps');
      await _updateLastSyncTime();
      return totalSteps;
    } catch (e) {
      print('[GoogleFitService] Error fetching steps for date: $e');
      return 0;
    }
  }

  /// Get weekly steps (last 7 days including today)
  Future<Map<DateTime, int>> getWeeklySteps() async {
    if (!_hasPermissions) {
      final hasPerms = await hasPermissions();
      if (!hasPerms) {
        print('[GoogleFitService] No permissions to read steps');
        return {};
      }
    }

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekAgo = today
          .subtract(const Duration(days: 6)); // 7 days total including today

      final healthData = await _health!.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: weekAgo,
        endTime: today.add(const Duration(days: 1)),
      );

      // Group steps by date
      Map<DateTime, int> stepsByDate = {};

      for (var data in healthData) {
        if (data.type == HealthDataType.STEPS) {
          final date = DateTime(
            data.dateFrom.year,
            data.dateFrom.month,
            data.dateFrom.day,
          );
          stepsByDate[date] =
              (stepsByDate[date] ?? 0) + (data.value as num).toInt();
        }
      }

      // Ensure all 7 days are present (fill with 0 if missing)
      for (int i = 0; i < 7; i++) {
        final date = today.subtract(Duration(days: i));
        stepsByDate.putIfAbsent(date, () => 0);
      }

      print(
          '[GoogleFitService] Weekly steps fetched: ${stepsByDate.length} days');
      await _updateLastSyncTime();
      return stepsByDate;
    } catch (e) {
      print('[GoogleFitService] Error fetching weekly steps: $e');
      return {};
    }
  }

  /// Get monthly steps (last 30 days including today)
  Future<Map<DateTime, int>> getMonthlySteps() async {
    if (!_hasPermissions) {
      final hasPerms = await hasPermissions();
      if (!hasPerms) {
        print('[GoogleFitService] No permissions to read steps');
        return {};
      }
    }

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final monthAgo = today
          .subtract(const Duration(days: 29)); // 30 days total including today

      final healthData = await _health!.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: monthAgo,
        endTime: today.add(const Duration(days: 1)),
      );

      // Group steps by date
      Map<DateTime, int> stepsByDate = {};

      for (var data in healthData) {
        if (data.type == HealthDataType.STEPS) {
          final date = DateTime(
            data.dateFrom.year,
            data.dateFrom.month,
            data.dateFrom.day,
          );
          stepsByDate[date] =
              (stepsByDate[date] ?? 0) + (data.value as num).toInt();
        }
      }

      // Ensure all 30 days are present (fill with 0 if missing)
      for (int i = 0; i < 30; i++) {
        final date = today.subtract(Duration(days: i));
        stepsByDate.putIfAbsent(date, () => 0);
      }

      print(
          '[GoogleFitService] Monthly steps fetched: ${stepsByDate.length} days');
      await _updateLastSyncTime();
      return stepsByDate;
    } catch (e) {
      print('[GoogleFitService] Error fetching monthly steps: $e');
      return {};
    }
  }

  /// Get total steps for a date range
  Future<int> getTotalSteps(DateTime start, DateTime end) async {
    if (!_hasPermissions) {
      final hasPerms = await hasPermissions();
      if (!hasPerms) {
        print('[GoogleFitService] No permissions to read steps');
        return 0;
      }
    }

    try {
      final healthData = await _health!.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: start,
        endTime: end,
      );

      int totalSteps = 0;
      for (var data in healthData) {
        if (data.type == HealthDataType.STEPS) {
          totalSteps += (data.value as num).toInt();
        }
      }

      print(
          '[GoogleFitService] Total steps from ${start.toIso8601String()} to ${end.toIso8601String()}: $totalSteps');
      await _updateLastSyncTime();
      return totalSteps;
    } catch (e) {
      print('[GoogleFitService] Error fetching total steps: $e');
      return 0;
    }
  }

  /// Get last sync timestamp
  Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastSyncKey);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    } catch (e) {
      print('[GoogleFitService] Error getting last sync time: $e');
      return null;
    }
  }

  /// Update last sync timestamp
  Future<void> _updateLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('[GoogleFitService] Error updating last sync time: $e');
    }
  }

  /// Check if Google Fit is enabled
  Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_enabledKey) ?? false;
    } catch (e) {
      print('[GoogleFitService] Error checking enabled status: $e');
      return false;
    }
  }

  /// Set Google Fit enabled status
  Future<void> _setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabled);
    } catch (e) {
      print('[GoogleFitService] Error setting enabled status: $e');
    }
  }

  /// Disable Google Fit integration
  Future<void> disable() async {
    await _setEnabled(false);
    _hasPermissions = false;
    print('[GoogleFitService] Disabled');
  }

  /// Write steps to Health Connect (for future use)
  Future<bool> writeSteps(int steps, DateTime dateFrom, DateTime dateTo) async {
    if (!_hasPermissions) {
      print('[GoogleFitService] No permissions to write steps');
      return false;
    }

    try {
      final success = await _health!.writeHealthData(
        value: steps.toDouble(),
        type: HealthDataType.STEPS,
        startTime: dateFrom,
        endTime: dateTo,
      );

      if (success) {
        print('[GoogleFitService] Successfully wrote $steps steps');
      } else {
        print('[GoogleFitService] Failed to write steps');
      }

      return success;
    } catch (e) {
      print('[GoogleFitService] Error writing steps: $e');
      return false;
    }
  }
}
