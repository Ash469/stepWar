import 'dart:math';
import '../database/database_helper.dart';
import '../models/user.dart';
import 'step_economy_service.dart';
import 'territory_service.dart';

class UserService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final StepEconomyService _economyService = StepEconomyService();
  final TerritoryService _territoryService = TerritoryService();

  /// Create a new user with starting conditions
  /// Implements game rules 3.1: Starting Conditions
  Future<String?> createUser(String nickname) async {
    // Check if nickname already exists
    final existingUser = await _dbHelper.getUserByNickname(nickname);
    if (existingUser != null) {
      return null; // Nickname already taken
    }

    try {
      // Create the user - this will also assign a random territory if available
      final userId = await _dbHelper.createUser(nickname);
      return userId;
    } catch (e) {
      return null;
    }
  }

  /// Get user by ID
  Future<GameUser?> getUser(String userId) async {
    return await _dbHelper.getUser(userId);
  }

  /// Get user by nickname
  Future<GameUser?> getUserByNickname(String nickname) async {
    return await _dbHelper.getUserByNickname(nickname);
  }

  /// Update user's step count and convert to game points
  Future<GameUser?> updateUserSteps(String userId, int newStepCount) async {
    try {
      return await _economyService.processStepUpdate(userId, newStepCount);
    } catch (e) {
      return null;
    }
  }

  /// Get user's complete game profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final user = await _dbHelper.getUser(userId);
    if (user == null) return null;

    final territories = await _territoryService.getUserTerritories(userId);
    final territoryStats = await _territoryService.getUserTerritoryStats(userId);
    final attackPower = await _economyService.getUserAttackPower(userId);
    final defensePower = await _economyService.getUserDefensePower(userId);

    return {
      'user': user,
      'territories': territories,
      'territory_stats': territoryStats,
      'attack_power': attackPower,
      'defense_power': defensePower,
      'can_attack_today': await _economyService.canUserAttackToday(userId),
    };
  }

  /// Get user statistics and rankings
  Future<Map<String, dynamic>?> getUserStats(String userId) async {
    final user = await _dbHelper.getUser(userId);
    if (user == null) return null;

    // Calculate derived statistics
    final winRate = user.totalAttacksLaunched > 0
        ? user.totalTerritoriesCaptured / user.totalAttacksLaunched
        : 0.0;

    final avgStepsPerDay = _calculateAvgStepsPerDay(user);
    final activityLevel = _getActivityLevel(avgStepsPerDay);

    return {
      'basic_stats': {
        'total_steps': user.totalSteps,
        'territories_owned': user.territoriesOwned,
        'attacks_launched': user.totalAttacksLaunched,
        'territories_captured': user.totalTerritoriesCaptured,
        'defenses_won': user.totalDefensesWon,
        'attack_points': user.attackPoints,
        'shield_points': user.shieldPoints,
      },
      'performance_metrics': {
        'attack_success_rate': winRate,
        'avg_steps_per_day': avgStepsPerDay.round(),
        'activity_level': activityLevel,
        'days_active': _calculateDaysActive(user),
      },
      'daily_status': {
        'attacks_used_today': user.attacksUsedToday,
        'attacks_remaining': 3 - user.attacksUsedToday, // Default daily limit
        'can_attack_today': await _economyService.canUserAttackToday(userId),
      },
    };
  }

  /// Get user leaderboard position
  Future<Map<String, dynamic>?> getUserRanking(String userId) async {
    final user = await _dbHelper.getUser(userId);
    if (user == null) return null;

    // This would require more complex queries in production
    // For now, return placeholder data
    return {
      'user_id': userId,
      'nickname': user.nickname,
      'global_rank': Random().nextInt(1000) + 1, // Placeholder
      'territories_rank': Random().nextInt(500) + 1, // Placeholder
      'steps_rank': Random().nextInt(2000) + 1, // Placeholder
      'attack_success_rank': Random().nextInt(800) + 1, // Placeholder
    };
  }

  /// Get user's attack history with analysis
  Future<List<Map<String, dynamic>>> getUserAttackHistory(String userId, {int limit = 20}) async {
    final user = await _dbHelper.getUser(userId);
    if (user == null) return [];

    final attacks = await _dbHelper.getUserAttacks(userId);
    
    return attacks.take(limit).map((attack) => {
      'attack': attack,
      'success': attack.successful,
      'efficiency': attack.stepsBurned > 0 
          ? (attack.successful ? 100.0 : (attack.attackPointsSpent / attack.stepsBurned) * 100)
          : 0.0,
      'date': attack.startedAt,
    }).toList();
  }

  /// Get recommended actions for user
  Future<List<Map<String, dynamic>>> getUserRecommendations(String userId) async {
    final user = await _dbHelper.getUser(userId);
    if (user == null) return [];

    final recommendations = <Map<String, dynamic>>[];

    // Check if user can attack today
    final canAttackToday = await _economyService.canUserAttackToday(userId);
    if (canAttackToday && user.attackPoints > 0) {
      final targets = await _territoryService.getAttackableTerritories(userId);
      if (targets.isNotEmpty) {
        recommendations.add({
          'type': 'attack',
          'priority': 'high',
          'title': 'Launch Attack',
          'description': 'You have ${user.attackPoints} attack points. Consider attacking ${targets.first.name}.',
          'action_data': {
            'target_territory': targets.first,
            'attack_points_available': user.attackPoints,
          },
        });
      }
    }

    // Check if user should reinforce territories
    final userTerritories = await _territoryService.getUserTerritories(userId);
    final vulnerableTerritories = userTerritories
        .where((t) => t.currentShield < t.maxShield * 0.5)
        .toList();
    
    if (vulnerableTerritories.isNotEmpty && user.shieldPoints > 0) {
      recommendations.add({
        'type': 'defend',
        'priority': 'medium',
        'title': 'Reinforce Territories',
        'description': 'You have ${vulnerableTerritories.length} territories with low shields.',
        'action_data': {
          'vulnerable_territories': vulnerableTerritories.take(3).toList(),
          'shield_points_available': user.shieldPoints,
        },
      });
    }

    // Check if user needs more steps
    if (user.attackPoints < 10 && user.shieldPoints < 10) {
      recommendations.add({
        'type': 'walk',
        'priority': 'low',
        'title': 'Get Moving!',
        'description': 'Walk more to earn attack and shield points.',
        'action_data': {
          'steps_needed_for_attack': await _economyService.stepsNeededForAttackPoints(10),
          'steps_needed_for_defense': await _economyService.stepsNeededForShieldPoints(10),
        },
      });
    }

    return recommendations;
  }

  /// Update user preferences
  Future<bool> updateUserPreferences({
    required String userId,
    bool? notificationsEnabled,
    String? deviceToken,
  }) async {
    final user = await _dbHelper.getUser(userId);
    if (user == null) return false;

    final updatedUser = user.copyWith(
      notificationsEnabled: notificationsEnabled ?? user.notificationsEnabled,
      deviceToken: deviceToken ?? user.deviceToken,
    );

    try {
      await _dbHelper.updateUser(updatedUser);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get users for leaderboard
  Future<List<Map<String, dynamic>>> getUserLeaderboard({
    String sortBy = 'territories',
    int limit = 10,
  }) async {
    // This would require complex queries in production
    // For now, return placeholder implementation
    return [];
  }

  /// Check if user needs daily reset
  Future<void> checkAndResetDailyLimits(String userId) async {
    final user = await _dbHelper.getUser(userId);
    if (user == null) return;

    if (user.needsAttackReset) {
      await _dbHelper.resetDailyAttackCounts();
    }
  }

  /// Get user achievement progress
  Future<List<Map<String, dynamic>>> getUserAchievements(String userId) async {
    final user = await _dbHelper.getUser(userId);
    if (user == null) return [];

    final achievements = <Map<String, dynamic>>[];

    // Territory-based achievements
    achievements.add({
      'id': 'first_territory',
      'name': 'First Conquest',
      'description': 'Capture your first territory',
      'completed': user.territoriesOwned > 0,
      'progress': user.territoriesOwned >= 1 ? 1.0 : 0.0,
    });

    achievements.add({
      'id': 'territory_collector',
      'name': 'Territory Collector',
      'description': 'Own 5 territories',
      'completed': user.territoriesOwned >= 5,
      'progress': (user.territoriesOwned / 5).clamp(0.0, 1.0),
    });

    // Attack-based achievements
    achievements.add({
      'id': 'first_attack',
      'name': 'First Strike',
      'description': 'Launch your first attack',
      'completed': user.totalAttacksLaunched > 0,
      'progress': user.totalAttacksLaunched >= 1 ? 1.0 : 0.0,
    });

    achievements.add({
      'id': 'conqueror',
      'name': 'Conqueror',
      'description': 'Successfully capture 10 territories',
      'completed': user.totalTerritoriesCaptured >= 10,
      'progress': (user.totalTerritoriesCaptured / 10).clamp(0.0, 1.0),
    });

    // Step-based achievements
    achievements.add({
      'id': 'walker',
      'name': 'Walker',
      'description': 'Walk 10,000 steps',
      'completed': user.totalSteps >= 10000,
      'progress': (user.totalSteps / 10000).clamp(0.0, 1.0),
    });

    achievements.add({
      'id': 'marathon',
      'name': 'Marathon',
      'description': 'Walk 100,000 steps',
      'completed': user.totalSteps >= 100000,
      'progress': (user.totalSteps / 100000).clamp(0.0, 1.0),
    });

    return achievements;
  }

  /// Calculate average steps per day
  double _calculateAvgStepsPerDay(GameUser user) {
    final now = DateTime.now();
    final daysSinceCreation = now.difference(user.createdAt).inDays + 1;
    return user.totalSteps / daysSinceCreation;
  }

  /// Get activity level based on average steps
  String _getActivityLevel(double avgStepsPerDay) {
    if (avgStepsPerDay >= 10000) return 'Very Active';
    if (avgStepsPerDay >= 7500) return 'Active';
    if (avgStepsPerDay >= 5000) return 'Moderate';
    if (avgStepsPerDay >= 2500) return 'Light';
    return 'Sedentary';
  }

  /// Calculate days active
  int _calculateDaysActive(GameUser user) {
    final now = DateTime.now();
    return now.difference(user.createdAt).inDays;
  }

  /// Delete user (for GDPR compliance)
  Future<bool> deleteUser(String userId) async {
    try {
      // In production, this would need to handle:
      // - Removing user from territories
      // - Cleaning up attack records
      // - Ensuring referential integrity
      // For now, this is a placeholder
      return false; // Not implemented yet
    } catch (e) {
      return false;
    }
  }

  /// Export user data (for GDPR compliance)
  Future<Map<String, dynamic>?> exportUserData(String userId) async {
    final user = await _dbHelper.getUser(userId);
    if (user == null) return null;

    final territories = await _territoryService.getUserTerritories(userId);
    final attacks = await _dbHelper.getUserAttacks(userId);

    return {
      'user_data': user.toMap(),
      'territories': territories.map((t) => t.toMap()).toList(),
      'attack_history': attacks.map((a) => a.toMap()).toList(),
      'export_timestamp': DateTime.now().toIso8601String(),
    };
  }
}
