/// Data model for daily step count
class DailyStepData {
  final DateTime date;
  final int steps;
  final String source; // 'pedometer', 'google_fit', 'merged'

  DailyStepData({
    required this.date,
    required this.steps,
    required this.source,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'steps': steps,
      'source': source,
    };
  }

  factory DailyStepData.fromJson(Map<String, dynamic> json) {
    return DailyStepData(
      date: DateTime.parse(json['date']),
      steps: json['steps'],
      source: json['source'],
    );
  }

  @override
  String toString() {
    return 'DailyStepData(date: ${date.toIso8601String().split('T')[0]}, steps: $steps, source: $source)';
  }
}

/// Data model for weekly step statistics
class WeeklyStepStats {
  final List<DailyStepData> dailyData;
  final int totalSteps;
  final double averageSteps;
  final DateTime weekStart;
  final DateTime weekEnd;

  WeeklyStepStats({
    required this.dailyData,
    required this.totalSteps,
    required this.averageSteps,
    required this.weekStart,
    required this.weekEnd,
  });

  /// Create weekly stats from a map of date to steps
  factory WeeklyStepStats.fromStepsMap(Map<DateTime, int> stepsMap,
      {String source = 'google_fit'}) {
    final sortedDates = stepsMap.keys.toList()..sort();

    if (sortedDates.isEmpty) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return WeeklyStepStats(
        dailyData: [],
        totalSteps: 0,
        averageSteps: 0.0,
        weekStart: today.subtract(const Duration(days: 6)),
        weekEnd: today,
      );
    }

    final dailyData = sortedDates.map((date) {
      return DailyStepData(
        date: date,
        steps: stepsMap[date] ?? 0,
        source: source,
      );
    }).toList();

    final totalSteps = dailyData.fold<int>(0, (sum, data) => sum + data.steps);
    final averageSteps =
        dailyData.isNotEmpty ? totalSteps / dailyData.length : 0.0;

    return WeeklyStepStats(
      dailyData: dailyData,
      totalSteps: totalSteps,
      averageSteps: averageSteps,
      weekStart: sortedDates.first,
      weekEnd: sortedDates.last,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dailyData': dailyData.map((d) => d.toJson()).toList(),
      'totalSteps': totalSteps,
      'averageSteps': averageSteps,
      'weekStart': weekStart.toIso8601String(),
      'weekEnd': weekEnd.toIso8601String(),
    };
  }

  factory WeeklyStepStats.fromJson(Map<String, dynamic> json) {
    return WeeklyStepStats(
      dailyData: (json['dailyData'] as List)
          .map((d) => DailyStepData.fromJson(d))
          .toList(),
      totalSteps: json['totalSteps'],
      averageSteps: json['averageSteps'],
      weekStart: DateTime.parse(json['weekStart']),
      weekEnd: DateTime.parse(json['weekEnd']),
    );
  }

  @override
  String toString() {
    return 'WeeklyStepStats(total: $totalSteps, avg: ${averageSteps.toStringAsFixed(0)}, days: ${dailyData.length})';
  }
}

/// Data model for monthly step statistics
class MonthlyStepStats {
  final List<DailyStepData> dailyData;
  final int totalSteps;
  final double averageSteps;
  final DateTime monthStart;
  final DateTime monthEnd;

  MonthlyStepStats({
    required this.dailyData,
    required this.totalSteps,
    required this.averageSteps,
    required this.monthStart,
    required this.monthEnd,
  });

  /// Create monthly stats from a map of date to steps
  factory MonthlyStepStats.fromStepsMap(Map<DateTime, int> stepsMap,
      {String source = 'google_fit'}) {
    final sortedDates = stepsMap.keys.toList()..sort();

    if (sortedDates.isEmpty) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return MonthlyStepStats(
        dailyData: [],
        totalSteps: 0,
        averageSteps: 0.0,
        monthStart: today.subtract(const Duration(days: 29)),
        monthEnd: today,
      );
    }

    final dailyData = sortedDates.map((date) {
      return DailyStepData(
        date: date,
        steps: stepsMap[date] ?? 0,
        source: source,
      );
    }).toList();

    final totalSteps = dailyData.fold<int>(0, (sum, data) => sum + data.steps);
    final averageSteps =
        dailyData.isNotEmpty ? totalSteps / dailyData.length : 0.0;

    return MonthlyStepStats(
      dailyData: dailyData,
      totalSteps: totalSteps,
      averageSteps: averageSteps,
      monthStart: sortedDates.first,
      monthEnd: sortedDates.last,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dailyData': dailyData.map((d) => d.toJson()).toList(),
      'totalSteps': totalSteps,
      'averageSteps': averageSteps,
      'monthStart': monthStart.toIso8601String(),
      'monthEnd': monthEnd.toIso8601String(),
    };
  }

  factory MonthlyStepStats.fromJson(Map<String, dynamic> json) {
    return MonthlyStepStats(
      dailyData: (json['dailyData'] as List)
          .map((d) => DailyStepData.fromJson(d))
          .toList(),
      totalSteps: json['totalSteps'],
      averageSteps: json['averageSteps'],
      monthStart: DateTime.parse(json['monthStart']),
      monthEnd: DateTime.parse(json['monthEnd']),
    );
  }

  @override
  String toString() {
    return 'MonthlyStepStats(total: $totalSteps, avg: ${averageSteps.toStringAsFixed(0)}, days: ${dailyData.length})';
  }
}
