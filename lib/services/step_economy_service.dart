import '../database/database_helper.dart';
import '../models/game_config.dart';
import '../models/user.dart';
import 'auth_service.dart';

class StepEconomyService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // Cached game config for performance
  GameConfig? _cachedConfig;
  DateTime? _configCacheTime;
  static const Duration _configCacheExpiry = Duration(minutes: 5);

  /// Get current game configuration with caching
  Future<GameConfig> getGameConfig() async {
    final now = DateTime.now();
    
    if (_cachedConfig != null && 
        _configCacheTime != null && 
        now.difference(_configCacheTime!).compareTo(_configCacheExpiry) < 0) {
      return _cachedConfig!;
    }
    
    _cachedConfig = await _dbHelper.getGameConfig();
    _configCacheTime = now;
    return _cachedConfig!;
  }

  /// Convert steps to attack points
  /// Rule: 100 steps = 1 Attack Point (configurable)
  Future<int> stepsToAttackPoints(int steps) async {
    final config = await getGameConfig();
    if (config.stepsPerAttackPoint <= 0) return 0; // Avoid division by zero
    return steps ~/ config.stepsPerAttackPoint;
  }

  /// Convert attack points to shield hits
  /// Rule: 10 Attack Points = 1 Shield Hit (configurable)
  Future<int> attackPointsToShieldHits(int attackPoints) async {
    final config = await getGameConfig();
    if (config.attackPointsPerShieldHit <= 0) return 0;
    return attackPoints ~/ config.attackPointsPerShieldHit;
  }

  /// Convert steps directly to shield hits
  /// Rule: 1,000 steps = 1 shield hit (100 steps → 1 attack point → 1/10 shield hit)
  Future<int> stepsToShieldHits(int steps) async {
    final config = await getGameConfig();
    if (config.stepsPerShieldHit <= 0) return 0;
    return steps ~/ config.stepsPerShieldHit;
  }

  /// Convert steps to shield points (for defending)
  /// Rule: 100 steps = 1 Shield Point (configurable)
  Future<int> stepsToShieldPoints(int steps) async {
    final config = await getGameConfig();
    if (config.stepsPerShieldPoint <= 0) return 0;
    return steps ~/ config.stepsPerShieldPoint;
  }

  /// Calculate how many steps needed for a specific number of attack points
  Future<int> stepsNeededForAttackPoints(int attackPoints) async {
    final config = await getGameConfig();
    return attackPoints * config.stepsPerAttackPoint;
  }

  /// Calculate how many steps needed for a specific number of shield hits
  Future<int> stepsNeededForShieldHits(int shieldHits) async {
    final config = await getGameConfig();
    return shieldHits * config.stepsPerShieldHit;
  }

  /// Calculate how many steps needed for a specific number of shield points
  Future<int> stepsNeededForShieldPoints(int shieldPoints) async {
    final config = await getGameConfig();
    return shieldPoints * config.stepsPerShieldPoint;
  }

  /// Update user's step count and convert to game points.
  /// This now accepts the full GameUser object to avoid incorrect DB lookups.
  Future<GameUser> processStepUpdate(GameUser user, int rawStepCount) async {
    // FIX: The logic here was flawed. 'user.totalSteps' is being used as the last
    // synced *daily* step count. The original logic had a bug that prevented
    // new users (with 0 steps) from ever getting points. This revised logic is robust.
    
    // 'rawStepCount' is the current total daily steps from the device.
    // 'user.totalSteps' is the last daily step count we synced for this user.
    final stepDifference = rawStepCount - user.totalSteps;

    if (stepDifference <= 0) {
      // No new steps to process, or the counter was reset (new day).
      // Return the user object as is, without changing points.
      return user;
    }

    // Calculate total points that *should* have been awarded for all of today's steps.
    final totalAttackPointsFromAllSteps = await stepsToAttackPoints(rawStepCount);
    final totalShieldPointsFromAllSteps = await stepsToShieldPoints(rawStepCount);

    // Calculate points that were *already* awarded based on the previous step count.
    final previouslyAwardedAttackPoints = await stepsToAttackPoints(user.totalSteps);
    final previouslyAwardedShieldPoints = await stepsToShieldPoints(user.totalSteps);

    // The new points to add are the difference between the total deserved and what was already given.
    // This correctly handles fractional steps (e.g., earning 1 point after 18 steps if 10 steps = 1 point).
    final newAttackPointsToAdd = totalAttackPointsFromAllSteps - previouslyAwardedAttackPoints;
    final newShieldPointsToAdd = totalShieldPointsFromAllSteps - previouslyAwardedShieldPoints;

    // Only create a new user object if something actually changed.
    if (newAttackPointsToAdd > 0 || newShieldPointsToAdd > 0) {
        final updatedUser = user.copyWith(
            // Update 'totalSteps' to the latest daily count for the next sync cycle.
            totalSteps: rawStepCount,
            attackPoints: user.attackPoints + newAttackPointsToAdd,
            shieldPoints: user.shieldPoints + newShieldPointsToAdd,
        );
        return updatedUser;
    } else {
        // Even if no new points were earned (e.g., walked 9 steps, needs 10 for a point),
        // we should still update the step count in the user object for the next sync.
        return user.copyWith(totalSteps: rawStepCount);
    }
  }


  /// Spend attack points (returns updated user or null if insufficient points)
  Future<GameUser?> spendAttackPoints(String userId, int pointsToSpend) async {
    final user = await _dbHelper.getUser(userId);
    if (user == null || user.attackPoints < pointsToSpend) {
      return null;
    }

    final updatedUser = user.copyWith(
      attackPoints: user.attackPoints - pointsToSpend,
    );

    await _dbHelper.updateUser(updatedUser);
    return updatedUser;
  }

  /// Spend shield points (returns updated user or null if insufficient points)
  Future<GameUser?> spendShieldPoints(String userId, int pointsToSpend) async {
    final user = await _dbHelper.getUser(userId);
    if (user == null || user.shieldPoints < pointsToSpend) {
      return null;
    }

    final updatedUser = user.copyWith(
      shieldPoints: user.shieldPoints - pointsToSpend,
    );

    await _dbHelper.updateUser(updatedUser);
    return updatedUser;
  }

  /// Check if user can attack today (daily limit check)
  Future<bool> canUserAttackToday(String userId) async {
    final user = await _dbHelper.getUser(userId);
    if (user == null) return false;

    final config = await getGameConfig();
    
    // Check if attack count needs reset
    if (user.needsAttackReset) {
      await _resetUserDailyAttacks(userId);
      return true; // After reset, user can attack
    }

    return user.attacksUsedToday < config.dailyAttackLimit;
  }

  /// Increment user's daily attack count
  Future<void> incrementUserAttackCount(String userId) async {
    final user = await _dbHelper.getUser(userId);
    if (user == null) return;

    final updatedUser = user.copyWith(
      attacksUsedToday: user.attacksUsedToday + 1,
      totalAttacksLaunched: user.totalAttacksLaunched + 1,
    );

    await _dbHelper.updateUser(updatedUser);
  }

  /// Reset user's daily attack count
  Future<void> _resetUserDailyAttacks(String userId) async {
    final user = await _dbHelper.getUser(userId);
    if (user == null) return;

    final now = DateTime.now();
    final updatedUser = user.copyWith(
      attacksUsedToday: 0,
      lastAttackReset: now,
    );

    await _dbHelper.updateUser(updatedUser);
  }

  /// Get attack cost breakdown for UI display
  Future<Map<String, int>> getAttackCostBreakdown(int shieldHitsWanted) async {
    final config = await getGameConfig();
    
    final attackPointsNeeded = shieldHitsWanted * config.attackPointsPerShieldHit;
    final stepsNeeded = attackPointsNeeded * config.stepsPerAttackPoint;
    
    return {
      'shield_hits': shieldHitsWanted,
      'attack_points_needed': attackPointsNeeded,
      'steps_needed': stepsNeeded,
    };
  }

  /// Get shield defense cost breakdown for UI display
  Future<Map<String, int>> getDefenseCostBreakdown(int shieldPointsWanted) async {
    final config = await getGameConfig();
    final stepsNeeded = shieldPointsWanted * config.stepsPerShieldPoint;
    
    return {
      'shield_points': shieldPointsWanted,
      'steps_needed': stepsNeeded,
    };
  }

  /// Calculate user's potential attack power
  Future<Map<String, int>> getUserAttackPower(String userId) async {
    final user = await _dbHelper.getUser(userId);
    if (user == null) {
      return {
        'attack_points': 0,
        'max_shield_hits': 0,
        'steps_represented': 0,
      };
    }

    final config = await getGameConfig();
    final maxShieldHits = user.attackPoints ~/ config.attackPointsPerShieldHit;
    final stepsRepresented = user.attackPoints * config.stepsPerAttackPoint;

    return {
      'attack_points': user.attackPoints,
      'max_shield_hits': maxShieldHits,
      'steps_represented': stepsRepresented,
    };
  }

  /// Calculate user's potential defense power
  Future<Map<String, int>> getUserDefensePower(String userId) async {
    final user = await _dbHelper.getUser(userId);
    if (user == null) {
      return {
        'shield_points': 0,
        'steps_represented': 0,
      };
    }

    final config = await getGameConfig();
    final stepsRepresented = user.shieldPoints * config.stepsPerShieldPoint;

    return {
      'shield_points': user.shieldPoints,
      'steps_represented': stepsRepresented,
    };
  }

  /// Clear the config cache (call when config is updated)
  void clearConfigCache() {
    _cachedConfig = null;
    _configCacheTime = null;
  }
}
