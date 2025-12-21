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

  Future<void> saveStepsForDate(String date, int steps) async {
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
}
