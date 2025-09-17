import 'package:flutter/foundation.dart';
import '../models/daily_activity.dart';
import 'firebase_game_database.dart';

class DailyActivityService {
  static final DailyActivityService _instance = DailyActivityService._internal();
  factory DailyActivityService() => _instance;
  DailyActivityService._internal();

  final FirebaseGameDatabase _gameDB = FirebaseGameDatabase();

  // ==========================================================================
  // DAILY ACTIVITY TRACKING
  // ==========================================================================

  /// Get or create today's activity record for user
  Future<DailyActivity> getTodayActivity(String userId, String userNickname) async {
    try {
      return await _gameDB.getTodayActivity(userId, userNickname);
    } catch (e) {
      if (kDebugMode) print('❌ [DailyActivity] Error getting today activity: $e');
      
      // Return default activity on error
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return DailyActivity(
        id: DailyActivity.generateTodayId(userId),
        userId: userId,
        userNickname: userNickname,
        date: today,
        createdAt: now,
        updatedAt: now,
      );
    }
  }

  /// Update today's step count
  Future<bool> updateDailySteps({
    required String userId,
    required String userNickname,
    required int steps,
  }) async {
    try {
      if (kDebugMode) print('📊 [DailyActivity] Updating daily steps: $steps for $userNickname');
      
      return await _gameDB.updateDailySteps(userId, userNickname, steps);
    } catch (e) {
      if (kDebugMode) print('❌ [DailyActivity] Error updating daily steps: $e');
      return false;
    }
  }

  /// Record battle started
  Future<bool> recordBattleStarted({
    required String userId,
    required String userNickname,
    required String battleId,
    required String territoryId,
    required String territoryName,
    required bool isAttacker,
  }) async {
    try {
      final activity = await getTodayActivity(userId, userNickname);
      
      final updatedActivity = activity.copyWith(
        battlesStartedToday: activity.battlesStartedToday + 1,
        firstAttackToday: isAttacker && !activity.firstAttackToday,
        firstDefenseToday: !isAttacker && !activity.firstDefenseToday,
        updatedAt: DateTime.now(),
      );
      
      final success = await _updateDailyActivity(updatedActivity);
      
      if (kDebugMode && success) {
        print('⚔️ [DailyActivity] Recorded battle started for $userNickname');
        print('   • Battle ID: $battleId');
        print('   • Territory: $territoryName');
        print('   • Role: ${isAttacker ? "Attacker" : "Defender"}');
        print('   • Total battles today: ${updatedActivity.battlesStartedToday}');
      }
      
      return success;
    } catch (e) {
      if (kDebugMode) print('❌ [DailyActivity] Error recording battle started: $e');
      return false;
    }
  }

  /// Record battle outcome
  Future<bool> recordBattleOutcome({
    required String userId,
    required String userNickname,
    required String battleId,
    required bool won,
    required int attackPointsSpent,
    required int shieldPointsUsed,
  }) async {
    try {
      final activity = await getTodayActivity(userId, userNickname);
      
      final updatedActivity = activity.copyWith(
        battlesWonToday: won ? activity.battlesWonToday + 1 : activity.battlesWonToday,
        battlesLostToday: !won ? activity.battlesLostToday + 1 : activity.battlesLostToday,
        attackPointsSpentToday: activity.attackPointsSpentToday + attackPointsSpent,
        shieldPointsUsedToday: activity.shieldPointsUsedToday + shieldPointsUsed,
        updatedAt: DateTime.now(),
      );
      
      final success = await _updateDailyActivity(updatedActivity);
      
      if (kDebugMode && success) {
        print('🏆 [DailyActivity] Recorded battle outcome for $userNickname: ${won ? "WON" : "LOST"}');
        print('   • Win/Loss record today: ${updatedActivity.battlesWonToday}W/${updatedActivity.battlesLostToday}L');
        print('   • Points spent: ${attackPointsSpent}AP/${shieldPointsUsed}SP');
      }
      
      return success;
    } catch (e) {
      if (kDebugMode) print('❌ [DailyActivity] Error recording battle outcome: $e');
      return false;
    }
  }

  /// Record territory captured
  Future<bool> recordTerritoryGained({
    required String userId,
    required String userNickname,
    required String territoryId,
    required String territoryName,
  }) async {
    try {
      final activity = await getTodayActivity(userId, userNickname);
      
      final updatedActivity = activity.copyWith(
        ownedTerritoryIdToday: territoryId,
        ownedTerritoryNameToday: territoryName,
        gainedTerritoryToday: true,
        updatedAt: DateTime.now(),
      );
      
      final success = await _updateDailyActivity(updatedActivity);
      
      if (kDebugMode && success) {
        print('🏴‍☠️ [DailyActivity] Recorded territory gained: $territoryName for $userNickname');
      }
      
      return success;
    } catch (e) {
      if (kDebugMode) print('❌ [DailyActivity] Error recording territory gained: $e');
      return false;
    }
  }

  /// Record territory lost
  Future<bool> recordTerritoryLost({
    required String userId,
    required String userNickname,
    required String territoryId,
    required String territoryName,
  }) async {
    try {
      final activity = await getTodayActivity(userId, userNickname);
      
      final updatedActivity = activity.copyWith(
        lostTerritoryToday: true,
        ownedTerritoryIdToday: null, // Clear if this was their current territory
        ownedTerritoryNameToday: null,
        updatedAt: DateTime.now(),
      );
      
      final success = await _updateDailyActivity(updatedActivity);
      
      if (kDebugMode && success) {
        print('💔 [DailyActivity] Recorded territory lost: $territoryName for $userNickname');
      }
      
      return success;
    } catch (e) {
      if (kDebugMode) print('❌ [DailyActivity] Error recording territory lost: $e');
      return false;
    }
  }

  /// Update current territory ownership status
  Future<bool> updateCurrentTerritoryOwnership({
    required String userId,
    required String userNickname,
    String? territoryId,
    String? territoryName,
  }) async {
    try {
      final activity = await getTodayActivity(userId, userNickname);
      
      final updatedActivity = activity.copyWith(
        ownedTerritoryIdToday: territoryId,
        ownedTerritoryNameToday: territoryName,
        updatedAt: DateTime.now(),
      );
      
      return await _updateDailyActivity(updatedActivity);
    } catch (e) {
      if (kDebugMode) print('❌ [DailyActivity] Error updating territory ownership: $e');
      return false;
    }
  }

  // ==========================================================================
  // ANALYTICS & REPORTING
  // ==========================================================================

  /// Get user's activity for a specific date
  Future<DailyActivity?> getUserActivityForDate({
    required String userId,
    required String userNickname,
    required DateTime date,
  }) async {
    try {
      final dateId = DailyActivity.generateId(userId, date);
      
      // This would require implementing in FirebaseGameDatabase
      // For now, return null for dates other than today
      final today = DateTime.now();
      final targetDate = DateTime(date.year, date.month, date.day);
      final todayDate = DateTime(today.year, today.month, today.day);
      
      if (targetDate.isAtSameMomentAs(todayDate)) {
        return await getTodayActivity(userId, userNickname);
      }
      
      return null; // Would implement historical data fetching
    } catch (e) {
      if (kDebugMode) print('❌ [DailyActivity] Error getting activity for date: $e');
      return null;
    }
  }

  /// Get weekly activity summary
  Future<WeeklyActivitySummary> getWeeklyActivitySummary({
    required String userId,
    required String userNickname,
  }) async {
    try {
      // For MVP, we'll only have today's data
      // In full implementation, we'd fetch last 7 days
      final todayActivity = await getTodayActivity(userId, userNickname);
      
      return WeeklyActivitySummary(
        userId: userId,
        userNickname: userNickname,
        weekStartDate: DateTime.now().subtract(const Duration(days: 6)),
        weekEndDate: DateTime.now(),
        totalSteps: todayActivity.stepsToday,
        totalBattles: todayActivity.totalBattlesToday,
        totalWins: todayActivity.battlesWonToday,
        totalLosses: todayActivity.battlesLostToday,
        daysActive: todayActivity.stepsToday > 0 ? 1 : 0,
        averageStepsPerDay: todayActivity.stepsToday.toDouble(),
        stepGoalAchievedDays: todayActivity.isStepGoalMet ? 1 : 0,
        territoriesGained: todayActivity.gainedTerritoryToday ? 1 : 0,
        territoriesLost: todayActivity.lostTerritoryToday ? 1 : 0,
      );
    } catch (e) {
      if (kDebugMode) print('❌ [DailyActivity] Error getting weekly summary: $e');
      return WeeklyActivitySummary.empty(userId, userNickname);
    }
  }

  /// Get activity statistics for analytics
  Future<ActivityStatistics> getActivityStatistics(String userId, String userNickname) async {
    try {
      final todayActivity = await getTodayActivity(userId, userNickname);
      
      return ActivityStatistics(
        userId: userId,
        userNickname: userNickname,
        todaySteps: todayActivity.stepsToday,
        stepGoalProgress: todayActivity.stepGoalProgress,
        battlesToday: todayActivity.totalBattlesToday,
        winRateToday: todayActivity.winRateToday,
        attackPointsSpentToday: todayActivity.attackPointsSpentToday,
        shieldPointsUsedToday: todayActivity.shieldPointsUsedToday,
        hasTerritory: todayActivity.ownsTerritory,
        currentTerritoryName: todayActivity.ownedTerritoryNameToday,
        achievementsToday: _calculateTodayAchievements(todayActivity),
      );
    } catch (e) {
      if (kDebugMode) print('❌ [DailyActivity] Error getting activity statistics: $e');
      return ActivityStatistics.empty(userId, userNickname);
    }
  }

  // ==========================================================================
  // HELPER METHODS
  // ==========================================================================

  /// Update daily activity record
  Future<bool> _updateDailyActivity(DailyActivity activity) async {
    try {
      // Would implement this in FirebaseGameDatabase
      // For now, simulate success
      return await _gameDB.updateDailySteps(
        activity.userId,
        activity.userNickname,
        activity.stepsToday,
      );
    } catch (e) {
      if (kDebugMode) print('❌ [DailyActivity] Error updating daily activity: $e');
      return false;
    }
  }

  /// Calculate today's achievements
  List<String> _calculateTodayAchievements(DailyActivity activity) {
    final achievements = <String>[];
    
    if (activity.reachedStepGoalToday) {
      achievements.add('Step Goal Achieved');
    }
    
    if (activity.firstAttackToday) {
      achievements.add('First Attack');
    }
    
    if (activity.firstDefenseToday) {
      achievements.add('First Defense');
    }
    
    if (activity.gainedTerritoryToday) {
      achievements.add('Territory Captured');
    }
    
    if (activity.battlesWonToday >= 3) {
      achievements.add('Battle Streak');
    }
    
    if (activity.stepsToday >= 10000) {
      achievements.add('10K Steps');
    }
    
    return achievements;
  }

  /// Reset daily counters (would be called by a scheduled function)
  Future<bool> resetDailyCounters(String userId, String userNickname) async {
    try {
      // This would typically be handled by Firebase Functions
      // Called at midnight to reset daily counters
      if (kDebugMode) print('🔄 [DailyActivity] Resetting daily counters for $userNickname');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ [DailyActivity] Error resetting daily counters: $e');
      return false;
    }
  }
}

// ==========================================================================
// RESULT CLASSES
// ==========================================================================

class WeeklyActivitySummary {
  final String userId;
  final String userNickname;
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final int totalSteps;
  final int totalBattles;
  final int totalWins;
  final int totalLosses;
  final int daysActive;
  final double averageStepsPerDay;
  final int stepGoalAchievedDays;
  final int territoriesGained;
  final int territoriesLost;

  WeeklyActivitySummary({
    required this.userId,
    required this.userNickname,
    required this.weekStartDate,
    required this.weekEndDate,
    required this.totalSteps,
    required this.totalBattles,
    required this.totalWins,
    required this.totalLosses,
    required this.daysActive,
    required this.averageStepsPerDay,
    required this.stepGoalAchievedDays,
    required this.territoriesGained,
    required this.territoriesLost,
  });

  double get winRate => totalBattles > 0 ? totalWins / totalBattles : 0.0;
  int get netTerritoryChange => territoriesGained - territoriesLost;

  factory WeeklyActivitySummary.empty(String userId, String userNickname) {
    final now = DateTime.now();
    return WeeklyActivitySummary(
      userId: userId,
      userNickname: userNickname,
      weekStartDate: now.subtract(const Duration(days: 6)),
      weekEndDate: now,
      totalSteps: 0,
      totalBattles: 0,
      totalWins: 0,
      totalLosses: 0,
      daysActive: 0,
      averageStepsPerDay: 0.0,
      stepGoalAchievedDays: 0,
      territoriesGained: 0,
      territoriesLost: 0,
    );
  }
}

class ActivityStatistics {
  final String userId;
  final String userNickname;
  final int todaySteps;
  final double stepGoalProgress;
  final int battlesToday;
  final double winRateToday;
  final int attackPointsSpentToday;
  final int shieldPointsUsedToday;
  final bool hasTerritory;
  final String? currentTerritoryName;
  final List<String> achievementsToday;

  ActivityStatistics({
    required this.userId,
    required this.userNickname,
    required this.todaySteps,
    required this.stepGoalProgress,
    required this.battlesToday,
    required this.winRateToday,
    required this.attackPointsSpentToday,
    required this.shieldPointsUsedToday,
    required this.hasTerritory,
    required this.currentTerritoryName,
    required this.achievementsToday,
  });

  factory ActivityStatistics.empty(String userId, String userNickname) {
    return ActivityStatistics(
      userId: userId,
      userNickname: userNickname,
      todaySteps: 0,
      stepGoalProgress: 0.0,
      battlesToday: 0,
      winRateToday: 0.0,
      attackPointsSpentToday: 0,
      shieldPointsUsedToday: 0,
      hasTerritory: false,
      currentTerritoryName: null,
      achievementsToday: [],
    );
  }
}
