import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StepHistoryService {
  Map<String, int> _stepHistory = {};

  Future<void> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? historyJson = prefs.getString('step_history_map');

      if (historyJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(historyJson);
        _stepHistory = decoded.map((key, value) => MapEntry(key, value as int));
        print(
            '📊 StepHistoryService: Loaded step history with ${_stepHistory.length} entries');
      } else {
        _stepHistory = {};
        print('📊 StepHistoryService: No step history found, starting fresh');
      }
    } catch (e) {
      print(
          '📊 StepHistoryService ERROR loading step history: $e. Starting fresh.');
      _stepHistory = {};
    }
  }
    /// Validate date format (yyyy-MM-dd)
  bool _isValidDateFormat(String date) {
    try {
      final parsed = DateTime.parse(date);
      final formatted = DateFormat('yyyy-MM-dd').format(parsed);
      return formatted == date;
    } catch (e) {
      return false;
    }
  }

  /// Save steps for a specific date with validation
  Future<void> saveStepsForDate(String date, int steps) async {
    if (!_isValidDateFormat(date)) {
      print('📊 StepHistoryService ERROR: Invalid date format: $date');
      return;
    }
    if (steps < 0) {
      print(
          '📊 StepHistoryService ERROR: Negative steps value: $steps for date: $date');
      return;
    }
    _stepHistory[date] = steps;
    await _persistHistory();
    print('📊 StepHistoryService: Saved $steps steps for $date to history');
  }



  Future<void> _persistHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String historyJson = jsonEncode(_stepHistory);
      await prefs.setString('step_history_map', historyJson);
    } catch (e) {
      print('📊 StepHistoryService ERROR persisting step history: $e');
    }
  }

  int? getStepsForDate(String date) {
    return _stepHistory[date];
  }

  Map<String, int> getAllHistory() {
    return Map.unmodifiable(_stepHistory);
  }

  /// Get last N days of history including today
  Map<String, int> getLastNDays(int days) {
    final now = DateTime.now();
    final Map<String, int> result = {};

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      final steps = _stepHistory[dateString];
      if (steps != null) {
        result[dateString] = steps;
      }
    }

    return result;
  }

  /// Recover today's steps from history if available
  Future<int?> recoverTodaySteps() async {
    final todayString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final steps = _stepHistory[todayString];

    if (steps != null) {
      print(
          '📊 StepHistoryService: Recovered $steps steps for today from history');
      return steps;
    }

    return null;
  }

  /// Check if we have data for a specific date
  bool hasDataForDate(String date) {
    return _stepHistory.containsKey(date);
  }

  /// Get the most recent step count (useful for recovery)
  int? getMostRecentSteps() {
    if (_stepHistory.isEmpty) return null;

    final sortedDates = _stepHistory.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    return _stepHistory[sortedDates.first];
  }

  Future<void> cleanupOldEntries({int daysToKeep = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final cutoffString = DateFormat('yyyy-MM-dd').format(cutoffDate);

      final int beforeCount = _stepHistory.length;
      _stepHistory
          .removeWhere((date, steps) => date.compareTo(cutoffString) < 0);
      final int afterCount = _stepHistory.length;

      if (beforeCount != afterCount) {
        await _persistHistory();
        print(
            '📊 StepHistoryService: Cleaned up ${beforeCount - afterCount} old history entries');
      }
    } catch (e) {
      print('📊 StepHistoryService ERROR cleaning up history: $e');
    }
  }

  int? getTodaySteps() {
    final todayString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return getStepsForDate(todayString);
  }

  int? getYesterdaySteps() {
    final yesterdayString = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));
    return getStepsForDate(yesterdayString);
  }

  int getTotalDaysRecorded() {
    return _stepHistory.length;
  }

  Future<void> clearAllHistory() async {
    _stepHistory.clear();
    await _persistHistory();
    print('📊 StepHistoryService: Cleared all history');
  }

  /// Sync missing dates from a date range
  Future<void> fillMissingDates(
      DateTime startDate, DateTime endDate, int defaultSteps) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    for (var date = start;
        date.isBefore(end) || date.isAtSameMomentAs(end);
        date = date.add(const Duration(days: 1))) {
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      if (!_stepHistory.containsKey(dateString)) {
        await saveStepsForDate(dateString, defaultSteps);
      }
    }
  }
}
