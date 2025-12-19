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

  /// Helper to extract numeric value from HealthValue
  /// In health package 13.x, NumericHealthValue.toJson() returns Map with 'numericValue' key
  int _extractSteps(dynamic healthValue) {
    try {
      final json = healthValue.toJson();
      if (json is num) {
        return json.toInt();
      } else if (json is Map) {
        // NumericHealthValue.toJson() returns {"numericValue": 123.0}
        final numericValue = json['numericValue'];
        if (numericValue is num) {
          return numericValue.toInt();
        }
      }
      // Fallback: try toString and parse
      return int.tryParse(healthValue.toString()) ?? 0;
    } catch (e) {
      print(
          '[GoogleFitService] Error extracting steps: $e, value: $healthValue');
      return 0;
    }
  }

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
          totalSteps += _extractSteps(data.value);
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Pre-populate all 7 days with 0 steps - this ensures we always return data
    Map<DateTime, int> stepsByDate = {};
    for (int i = 0; i < 7; i++) {
      final date = today.subtract(Duration(days: i));
      stepsByDate[date] = 0;
    }

    // Check permissions
    if (!_hasPermissions) {
      final hasPerms = await hasPermissions();
      if (!hasPerms) {
        print(
            '[GoogleFitService] No permissions to read steps - returning 0-filled data');
        return stepsByDate; // Return 0-filled instead of empty
      }
    }

    try {
      final weekAgo = today.subtract(const Duration(days: 6));

      print(
          '[GoogleFitService] Fetching weekly steps from $weekAgo to $today...');

      final healthData = await _health!.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: weekAgo,
        endTime: today.add(const Duration(days: 1)),
      );

      print(
          '[GoogleFitService] Health Connect returned ${healthData.length} data points');

      // Merge actual data with pre-populated map
      for (var data in healthData) {
        if (data.type == HealthDataType.STEPS) {
          final date = DateTime(
            data.dateFrom.year,
            data.dateFrom.month,
            data.dateFrom.day,
          );
          final steps = _extractSteps(data.value);
          stepsByDate[date] = (stepsByDate[date] ?? 0) + steps;
          print(
              '[GoogleFitService] Added $steps steps for ${date.toIso8601String().split('T')[0]}');
        }
      }

      print(
          '[GoogleFitService] Weekly steps fetched: ${stepsByDate.length} days');
      await _updateLastSyncTime();
      return stepsByDate;
    } catch (e) {
      print('[GoogleFitService] Error fetching weekly steps: $e');
      return stepsByDate; // Return 0-filled instead of empty
    }
  }

  /// Get monthly steps (last 30 days including today)
  Future<Map<DateTime, int>> getMonthlySteps() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Pre-populate all 30 days with 0 steps - this ensures we always return data
    Map<DateTime, int> stepsByDate = {};
    for (int i = 0; i < 30; i++) {
      final date = today.subtract(Duration(days: i));
      stepsByDate[date] = 0;
    }

    // Check permissions
    if (!_hasPermissions) {
      final hasPerms = await hasPermissions();
      if (!hasPerms) {
        print(
            '[GoogleFitService] No permissions to read steps - returning 0-filled data');
        return stepsByDate; // Return 0-filled instead of empty
      }
    }

    try {
      final monthAgo = today.subtract(const Duration(days: 29));

      print(
          '[GoogleFitService] Fetching monthly steps from $monthAgo to $today...');

      final healthData = await _health!.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: monthAgo,
        endTime: today.add(const Duration(days: 1)),
      );

      print(
          '[GoogleFitService] Health Connect returned ${healthData.length} data points for monthly');

      // Merge actual data with pre-populated map
      for (var data in healthData) {
        if (data.type == HealthDataType.STEPS) {
          final date = DateTime(
            data.dateFrom.year,
            data.dateFrom.month,
            data.dateFrom.day,
          );
          final steps = _extractSteps(data.value);
          stepsByDate[date] = (stepsByDate[date] ?? 0) + steps;
        }
      }

      print(
          '[GoogleFitService] Monthly steps fetched: ${stepsByDate.length} days');
      await _updateLastSyncTime();
      return stepsByDate;
    } catch (e) {
      print('[GoogleFitService] Error fetching monthly steps: $e');
      return stepsByDate; // Return 0-filled instead of empty
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
          totalSteps += _extractSteps(data.value);
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

  /// 🧪 DEBUG: Test and console log all Health Connect data
  /// Call this method to see what data is available
  Future<void> debugHealthConnectData() async {
    print('');
    print('=' * 60);
    print('🧪 [DEBUG] TESTING HEALTH CONNECT DATA');
    print('=' * 60);

    // 1. Check initialization
    print('\n📋 Step 1: Checking initialization...');
    print('   _isInitialized: $_isInitialized');
    print('   _hasPermissions: $_hasPermissions');
    print('   _health is null: ${_health == null}');

    if (!_isInitialized) {
      print('   ⚠️ Not initialized, initializing now...');
      final init = await initialize();
      print('   Initialize result: $init');
    }

    // 2. Check permissions
    print('\n📋 Step 2: Checking permissions...');
    final hasPerms = await hasPermissions();
    print('   hasPermissions() returned: $hasPerms');
    print('   _hasPermissions is now: $_hasPermissions');

    // 3. Check if Health Connect is available
    print('\n📋 Step 3: Checking Health Connect availability...');
    try {
      final installed = await _health!.isHealthConnectAvailable();
      print('   Health Connect available: $installed');
    } catch (e) {
      print('   ❌ Error checking Health Connect: $e');
    }

    // 4. Try to fetch raw data
    print('\n📋 Step 4: Fetching raw step data for last 7 days...');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 6));

    print('   Date range: $weekAgo to ${today.add(const Duration(days: 1))}');

    try {
      final healthData = await _health!.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: weekAgo,
        endTime: today.add(const Duration(days: 1)),
      );

      print('   ✅ Raw data points returned: ${healthData.length}');

      if (healthData.isEmpty) {
        print('   ⚠️ NO DATA! Health Connect returned 0 data points.');
        print('   This could mean:');
        print('      - Google Fit is not syncing to Health Connect');
        print('      - Permissions were not granted correctly');
        print('      - No steps have been recorded');
      } else {
        print('\n📊 RAW DATA FROM HEALTH CONNECT:');
        print('-' * 50);

        // Track by source to identify duplicates
        Map<String, Map<String, int>> stepsBySourceAndDate = {};

        for (var data in healthData) {
          final dateStr =
              '${data.dateFrom.year}-${data.dateFrom.month.toString().padLeft(2, '0')}-${data.dateFrom.day.toString().padLeft(2, '0')}';
          final steps = _extractSteps(data.value);
          final source = data.sourceName ?? 'unknown';

          stepsBySourceAndDate[source] ??= {};
          stepsBySourceAndDate[source]![dateStr] =
              (stepsBySourceAndDate[source]![dateStr] ?? 0) + steps;
        }

        // Show breakdown by source
        print('\n📊 STEPS BY SOURCE:');
        print('-' * 50);
        stepsBySourceAndDate.forEach((source, dates) {
          print('\n   Source: $source');
          dates.forEach((date, steps) {
            print('      $date: $steps steps');
          });
        });

        // Show today's breakdown specifically
        final todayStr =
            '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
        print('\n⚠️ TODAY ($todayStr) BY SOURCE:');
        print('-' * 50);
        int totalToday = 0;
        stepsBySourceAndDate.forEach((source, dates) {
          final todaySteps = dates[todayStr] ?? 0;
          if (todaySteps > 0) {
            print('   $source: $todaySteps steps');
            totalToday += todaySteps;
          }
        });
        print('   TOTAL (with duplicates): $totalToday steps');
        print(
            '   ⚠️ If this is ~2x the real value, we have duplicate sources!');

        print(
            '\n📈 SUMMARY BY DATE (all sources combined - may include duplicates):');
        print('-' * 50);
        Map<String, int> stepsByDate = {};
        stepsBySourceAndDate.forEach((source, dates) {
          dates.forEach((date, steps) {
            stepsByDate[date] = (stepsByDate[date] ?? 0) + steps;
          });
        });
        final sortedDates = stepsByDate.keys.toList()..sort();
        for (var date in sortedDates) {
          print('   $date: ${stepsByDate[date]} steps');
        }
      }
    } catch (e) {
      print('   ❌ Error fetching data: $e');
    }

    print('\n' + '=' * 60);
    print('🧪 [DEBUG] END OF HEALTH CONNECT TEST');
    print('=' * 60);
    print('');
  }
}
