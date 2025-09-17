import 'package:flutter/foundation.dart';
import '../models/territory.dart';
import '../models/user.dart';
import '../models/battle.dart';
import 'firebase_game_database.dart';

class TerritoryService {
  static final TerritoryService _instance = TerritoryService._internal();
  factory TerritoryService() => _instance;
  TerritoryService._internal();

  final FirebaseGameDatabase _gameDB = FirebaseGameDatabase();

  // ==========================================================================
  // TERRITORY LIFECYCLE METHODS
  // ==========================================================================

  /// Check and update territory cooldown status
  Future<Territory?> updateTerritoryStatus(Territory territory) async {
    try {
      // Check if cooldown has expired
      if (territory.isInCooldown && territory.isCooldownExpired) {
        if (kDebugMode) print('⏰ [Territory] Cooldown expired for ${territory.name}');
        
        final updatedTerritory = territory.copyWith(
          status: TerritoryStatus.peaceful,
          clearCooldown: true,
          updatedAt: DateTime.now(),
        );
        
        await _gameDB.updateTerritory(updatedTerritory);
        return updatedTerritory;
      }
      
      return territory;
    } catch (e) {
      if (kDebugMode) print('❌ [Territory] Error updating territory status: $e');
      return territory;
    }
  }

  /// Get all territories with updated statuses
  Future<List<Territory>> getAllTerritoriesWithUpdatedStatus() async {
    try {
      final territories = await _gameDB.getAllTerritories();
      final updatedTerritories = <Territory>[];
      
      for (final territory in territories) {
        final updated = await updateTerritoryStatus(territory);
        updatedTerritories.add(updated ?? territory);
      }
      
      return updatedTerritories;
    } catch (e) {
      if (kDebugMode) print('❌ [Territory] Error getting territories: $e');
      return [];
    }
  }

  /// Get territories available for attack (peaceful status, not in cooldown)
  Future<List<Territory>> getAttackableTerritoriesForUser(String userId) async {
    try {
      final territories = await getAllTerritoriesWithUpdatedStatus();
      
      return territories.where((territory) {
        // Can't attack your own territory
        if (territory.ownerId == userId) return false;
        
        // Territory must be attackable
        return territory.canBeAttacked;
      }).toList();
    } catch (e) {
      if (kDebugMode) print('❌ [Territory] Error getting attackable territories: $e');
      return [];
    }
  }

  /// Get territories owned by a user
  Future<List<Territory>> getUserOwnedTerritories(String userId) async {
    try {
      final territories = await _gameDB.getUserTerritories(userId);
      final updatedTerritories = <Territory>[];
      
      for (final territory in territories) {
        final updated = await updateTerritoryStatus(territory);
        updatedTerritories.add(updated ?? territory);
      }
      
      return updatedTerritories;
    } catch (e) {
      if (kDebugMode) print('❌ [Territory] Error getting user territories: $e');
      return [];
    }
  }

  // ==========================================================================
  // ATTACK VALIDATION & EXECUTION
  // ==========================================================================

  /// Validate if a user can start an attack on a territory
  Future<AttackValidationResult> validateAttack({
    required String attackerId,
    required String territoryId,
  }) async {
    try {
      // Check if user can attack today (daily limit)
      final canAttackToday = await _gameDB.canUserAttackToday(attackerId);
      if (!canAttackToday) {
        return AttackValidationResult(
          isValid: false,
          errorMessage: 'You have reached your daily attack limit (3 attacks per day)',
          errorCode: AttackValidationError.dailyLimitReached,
        );
      }

      // Get and validate territory
      final territory = await _gameDB.getTerritory(territoryId);
      if (territory == null) {
        return AttackValidationResult(
          isValid: false,
          errorMessage: 'Territory not found',
          errorCode: AttackValidationError.territoryNotFound,
        );
      }

      // Update territory status if needed
      final updatedTerritory = await updateTerritoryStatus(territory);
      final targetTerritory = updatedTerritory ?? territory;

      // Check if territory is owned by the attacker
      if (targetTerritory.ownerId == attackerId) {
        return AttackValidationResult(
          isValid: false,
          errorMessage: 'You cannot attack your own territory',
          errorCode: AttackValidationError.ownTerritory,
        );
      }

      // Check if territory can be attacked
      if (!targetTerritory.canBeAttacked) {
        String message;
        switch (targetTerritory.status) {
          case TerritoryStatus.underAttack:
            message = 'Territory is already under attack';
            break;
          case TerritoryStatus.cooldown:
            final remainingTime = targetTerritory.cooldownUntil?.difference(DateTime.now());
            if (remainingTime != null && remainingTime.inHours > 0) {
              message = 'Territory is in ${remainingTime.inHours}h cooldown';
            } else {
              message = 'Territory is in cooldown';
            }
            break;
          default:
            message = 'Territory cannot be attacked right now';
        }
        
        return AttackValidationResult(
          isValid: false,
          errorMessage: message,
          errorCode: AttackValidationError.territoryNotAttackable,
        );
      }

      // Check if there are any active battles on this territory
      final activeBattles = await _gameDB.getActiveBattlesForTerritory(territoryId);
      if (activeBattles.isNotEmpty) {
        return AttackValidationResult(
          isValid: false,
          errorMessage: 'Territory is already being attacked by another player',
          errorCode: AttackValidationError.alreadyUnderAttack,
        );
      }

      return AttackValidationResult(
        isValid: true,
        territory: targetTerritory,
      );
      
    } catch (e) {
      if (kDebugMode) print('❌ [Territory] Error validating attack: $e');
      return AttackValidationResult(
        isValid: false,
        errorMessage: 'Failed to validate attack. Please try again.',
        errorCode: AttackValidationError.systemError,
      );
    }
  }

  /// Execute an attack on a territory
  Future<AttackResult> executeAttack({
    required GameUser attacker,
    required String territoryId,
  }) async {
    try {
      if (kDebugMode) print('⚔️ [Territory] Executing attack on $territoryId by ${attacker.nickname}');

      // Validate attack
      final validation = await validateAttack(
        attackerId: attacker.id,
        territoryId: territoryId,
      );

      if (!validation.isValid) {
        return AttackResult(
          success: false,
          errorMessage: validation.errorMessage,
          errorCode: validation.errorCode,
        );
      }

      // Start the battle
      final battle = await _gameDB.startAttack(
        attackerId: attacker.id,
        attackerNickname: attacker.nickname,
        territoryId: territoryId,
      );

      if (battle == null) {
        return AttackResult(
          success: false,
          errorMessage: 'Failed to start battle. Please try again.',
          errorCode: AttackValidationError.systemError,
        );
      }

      if (kDebugMode) {
        print('✅ [Territory] Attack started successfully!');
        print('   • Battle ID: ${battle.id}');
        print('   • Territory: ${battle.territoryName}');
        print('   • Initial Shield: ${battle.initialShield}');
      }

      return AttackResult(
        success: true,
        battle: battle,
        territory: validation.territory,
      );

    } catch (e) {
      if (kDebugMode) print('❌ [Territory] Error executing attack: $e');
      return AttackResult(
        success: false,
        errorMessage: 'Attack failed due to system error. Please try again.',
        errorCode: AttackValidationError.systemError,
      );
    }
  }

  // ==========================================================================
  // DEFENSE METHODS
  // ==========================================================================

  /// Process defense points for a territory under attack
  Future<DefenseResult> processDefense({
    required String battleId,
    required int shieldPoints,
    required int stepsBurned,
  }) async {
    try {
      if (kDebugMode) print('🛡️ [Territory] Processing defense: $shieldPoints shield points');

      final success = await _gameDB.processDefensePoints(
        battleId: battleId,
        shieldPoints: shieldPoints,
        stepsBurned: stepsBurned,
      );

      if (!success) {
        return DefenseResult(
          success: false,
          errorMessage: 'Failed to process defense points',
        );
      }

      // Get updated battle information
      final battle = await _gameDB.getBattle(battleId);
      final territory = battle != null ? await _gameDB.getTerritory(battle.territoryId) : null;

      return DefenseResult(
        success: true,
        battle: battle,
        territory: territory,
        shieldPointsAdded: shieldPoints,
      );

    } catch (e) {
      if (kDebugMode) print('❌ [Territory] Error processing defense: $e');
      return DefenseResult(
        success: false,
        errorMessage: 'Defense failed due to system error',
      );
    }
  }

  // ==========================================================================
  // STEP TO GAME POINTS CONVERSION
  // ==========================================================================

  /// Convert steps to attack points based on game configuration
  Future<int> convertStepsToAttackPoints(int steps) async {
    try {
      final config = await _gameDB.getGameConfig();
      final stepsPerAttackPoint = config?.stepsPerAttackPoint ?? 100;
      return steps ~/ stepsPerAttackPoint;
    } catch (e) {
      if (kDebugMode) print('❌ [Territory] Error converting steps to attack points: $e');
      return steps ~/ 100; // Default conversion
    }
  }

  /// Convert steps to shield points based on game configuration
  Future<int> convertStepsToShieldPoints(int steps) async {
    try {
      final config = await _gameDB.getGameConfig();
      final stepsPerShieldPoint = config?.stepsPerShieldPoint ?? 100;
      return steps ~/ stepsPerShieldPoint;
    } catch (e) {
      if (kDebugMode) print('❌ [Territory] Error converting steps to shield points: $e');
      return steps ~/ 100; // Default conversion
    }
  }

  /// Calculate shield hits from attack points
  Future<int> calculateShieldHitsFromAttackPoints(int attackPoints) async {
    try {
      final config = await _gameDB.getGameConfig();
      final attackPointsPerHit = config?.attackPointsPerShieldHit ?? 10;
      return attackPoints ~/ attackPointsPerHit;
    } catch (e) {
      if (kDebugMode) print('❌ [Territory] Error calculating shield hits: $e');
      return attackPoints ~/ 10; // Default calculation
    }
  }

  // ==========================================================================
  // REAL-TIME BATTLE MONITORING
  // ==========================================================================

  /// Get active battle for a territory
  Future<Battle?> getActiveBattle(String territoryId) async {
    try {
      final battles = await _gameDB.getActiveBattlesForTerritory(territoryId);
      return battles.isNotEmpty ? battles.first : null;
    } catch (e) {
      if (kDebugMode) print('❌ [Territory] Error getting active battle: $e');
      return null;
    }
  }

  /// Listen to battle updates for real-time UI
  Stream<Battle?> listenToBattleUpdates(String battleId) {
    return _gameDB.listenToBattle(battleId);
  }

  /// Listen to territory updates for real-time UI
  Stream<List<Territory>> listenToTerritoryUpdates() {
    return _gameDB.listenToAllTerritories();
  }

  /// Listen to territories by status
  Stream<List<Territory>> listenToTerritoriesByStatus(TerritoryStatus status) {
    return _gameDB.listenToTerritoriesByStatus(status);
  }

  // ==========================================================================
  // MISSING METHODS - Added for compatibility
  // ==========================================================================

  /// Get all territories (compatibility method)
  Future<List<Territory>> getAllTerritories() async {
    return await getAllTerritoriesWithUpdatedStatus();
  }

  /// Get territories owned by user (compatibility method)
  Future<List<Territory>> getUserTerritories(String userId) async {
    return await getUserOwnedTerritories(userId);
  }

  /// Get attackable territories for user (compatibility method)
  Future<List<Territory>> getAttackableTerritories(String userId) async {
    return await getAttackableTerritoriesForUser(userId);
  }

  /// Get user territory statistics (compatibility method)
  Future<Map<String, dynamic>?> getUserTerritoryStats(String userId) async {
    try {
      final userTerritories = await getUserOwnedTerritories(userId);
      final attackableTerritories = await getAttackableTerritoriesForUser(userId);
      
      return {
        'territories_owned': userTerritories.length,
        'territories_attackable': attackableTerritories.length,
        'total_shield_points': userTerritories.fold<int>(0, (sum, t) => sum + t.currentShield),
        'avg_shield_level': userTerritories.isEmpty ? 0 : 
            userTerritories.fold<int>(0, (sum, t) => sum + t.currentShield) / userTerritories.length,
      };
    } catch (e) {
      if (kDebugMode) print('❌ [Territory] Error getting user territory stats: $e');
      return null;
    }
  }

  /// Reinforce a territory with shield points (compatibility method)
  Future<bool> reinforceTerritory({
    required String userId,
    required String territoryId,
    required int shieldPointsToSpend,
  }) async {
    try {
      // Get the territory
      final territory = await _gameDB.getTerritory(territoryId);
      if (territory == null || territory.ownerId != userId) {
        return false;
      }

      // Calculate new shield level (capped at max)
      final newShieldLevel = (territory.currentShield + shieldPointsToSpend).clamp(0, territory.maxShield);
      
      // Update territory
      final reinforcedTerritory = territory.copyWith(
        currentShield: newShieldLevel,
        updatedAt: DateTime.now(),
      );

      await _gameDB.updateTerritory(reinforcedTerritory);
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ [Territory] Error reinforcing territory: $e');
      return false;
    }
  }

  // ==========================================================================
  // UTILITY METHODS
  // ==========================================================================

  /// Get territory statistics for analytics
  Future<TerritoryStats> getTerritoryStats() async {
    try {
      final territories = await getAllTerritoriesWithUpdatedStatus();
      
      final stats = TerritoryStats();
      for (final territory in territories) {
        stats.totalTerritories++;
        
        if (territory.isOwned) {
          stats.ownedTerritories++;
        } else {
          stats.unownedTerritories++;
        }
        
        switch (territory.status) {
          case TerritoryStatus.peaceful:
            stats.peacefulTerritories++;
            break;
          case TerritoryStatus.underAttack:
            stats.territoriesUnderAttack++;
            break;
          case TerritoryStatus.cooldown:
            stats.territoriesInCooldown++;
            break;
        }
      }
      
      return stats;
    } catch (e) {
      if (kDebugMode) print('❌ [Territory] Error getting territory stats: $e');
      return TerritoryStats();
    }
  }
}

// ==========================================================================
// RESULT CLASSES
// ==========================================================================

class AttackValidationResult {
  final bool isValid;
  final String? errorMessage;
  final AttackValidationError? errorCode;
  final Territory? territory;

  AttackValidationResult({
    required this.isValid,
    this.errorMessage,
    this.errorCode,
    this.territory,
  });
}

class AttackResult {
  final bool success;
  final String? errorMessage;
  final AttackValidationError? errorCode;
  final Battle? battle;
  final Territory? territory;

  AttackResult({
    required this.success,
    this.errorMessage,
    this.errorCode,
    this.battle,
    this.territory,
  });
}

class DefenseResult {
  final bool success;
  final String? errorMessage;
  final Battle? battle;
  final Territory? territory;
  final int? shieldPointsAdded;

  DefenseResult({
    required this.success,
    this.errorMessage,
    this.battle,
    this.territory,
    this.shieldPointsAdded,
  });
}

class TerritoryStats {
  int totalTerritories = 0;
  int ownedTerritories = 0;
  int unownedTerritories = 0;
  int peacefulTerritories = 0;
  int territoriesUnderAttack = 0;
  int territoriesInCooldown = 0;
}

enum AttackValidationError {
  dailyLimitReached,
  territoryNotFound,
  ownTerritory,
  territoryNotAttackable,
  alreadyUnderAttack,
  systemError,
}
