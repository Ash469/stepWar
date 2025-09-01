import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/territory.dart';
import '../models/attack.dart';
import '../models/user.dart';
import 'step_economy_service.dart';

enum AttackResult {
  success,
  failed,
  insufficientPoints,
  territoryNotAttackable,
  dailyLimitReached,
  userNotFound,
  territoryNotFound,
  alreadyUnderAttack,
}

class AttackService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final StepEconomyService _economyService = StepEconomyService();
  final Uuid _uuid = Uuid();

  /// Launch an attack on a territory
  /// Implements game rules 3.5: Attack Rules
  Future<AttackResult> launchAttack({
    required String attackerId,
    required String territoryId,
    required int attackPoints,
  }) async {
    // Validate user exists
    final attacker = await _dbHelper.getUser(attackerId);
    if (attacker == null) return AttackResult.userNotFound;

    // Check daily attack limit
    final canAttackToday = await _economyService.canUserAttackToday(attackerId);
    if (!canAttackToday) return AttackResult.dailyLimitReached;

    // Validate territory exists and can be attacked
    final territory = await _dbHelper.getTerritory(territoryId);
    if (territory == null) return AttackResult.territoryNotFound;
    
    if (!territory.canBeAttacked || territory.isUnderAttack) {
      return AttackResult.territoryNotAttackable;
    }
    
    // Check if attacker has enough points
    if (attacker.attackPoints < attackPoints) {
      return AttackResult.insufficientPoints;
    }

    // Rule: Only one attacker can focus a territory at a time
    final existingAttack = await _dbHelper.getActiveAttackForTerritory(territoryId);
    if (existingAttack != null) {
      return AttackResult.alreadyUnderAttack;
    }

    try {
      // Start the attack process
      final wasSuccessful = await _executeAttackLaunch(
        attacker: attacker,
        territory: territory,
        attackPoints: attackPoints,
      );

      return wasSuccessful ? AttackResult.success : AttackResult.failed;
    } catch (e) {
      return AttackResult.failed;
    }
  }

  /// Execute the attack launch with database transactions
  /// Returns true if attack was successful (territory captured)
  Future<bool> _executeAttackLaunch({
    required GameUser attacker,
    required Territory territory,
    required int attackPoints,
  }) async {
    final now = DateTime.now();
    final attackId = _uuid.v4();

    // Calculate shield damage
    final shieldHits = await _economyService.attackPointsToShieldHits(attackPoints);
    final newShieldLevel = (territory.currentShield - shieldHits).clamp(0, territory.maxShield);

    // Create attack record
    final attack = Attack(
      id: attackId,
      attackerId: attacker.id,
      attackerNickname: attacker.nickname,
      territoryId: territory.id,
      territoryName: territory.name,
      defenderId: territory.ownerId,
      defenderNickname: territory.ownerNickname,
      status: AttackStatus.completed, // Mark as completed immediately
      startedAt: now,
      completedAt: now, // Complete immediately
      initialShield: territory.currentShield,
      attackPointsSpent: attackPoints,
      stepsBurned: await _economyService.stepsNeededForAttackPoints(attackPoints),
    );

    // Determine if attack is successful
    bool attackSuccessful = newShieldLevel <= 0;
    
    if (attackSuccessful) {
      // Territory captured!
      await _processTerritoryCapture(
        attack: attack,
        territory: territory,
        attacker: attacker,
        finalShieldLevel: 0,
      );
      return true;
    } else {
      // Attack failed, update territory and attack
      await _processFailedAttack(
        attack: attack,
        territory: territory,
        attacker: attacker,
        newShieldLevel: newShieldLevel,
      );
      return false;
    }
  }

  /// Process successful territory capture
  Future<void> _processTerritoryCapture({
    required Attack attack,
    required Territory territory,
    required GameUser attacker,
    required int finalShieldLevel,
  }) async {
    final now = DateTime.now();
    final config = await _economyService.getGameConfig();
    
    // Database operations to execute atomically
    final operations = <Map<String, dynamic>>[];

    // Update territory ownership
    final capturedTerritory = territory.copyWith(
      ownerId: attacker.id,
      ownerNickname: attacker.nickname,
      currentShield: config.baseShieldOnCapture, // Reset to base shield
      status: TerritoryStatus.cooldown,
      cooldownUntil: now.add(config.cooldownDuration),
      clearAttacker: true,
    );

    operations.add({
      'type': 'update',
      'table': 'territories',
      'data': capturedTerritory.toMap(),
      'where': 'id = ?',
      'whereArgs': [territory.id],
    });

    // Insert attack record
    operations.add({
      'type': 'insert',
      'table': 'attacks',
      'data': attack.copyWith(
        status: AttackStatus.completed,
        completedAt: now,
        successful: true,
        finalShield: finalShieldLevel,
      ).toMap(),
    });

    // Update attacker stats
    final updatedAttacker = attacker.copyWith(
      attackPoints: attacker.attackPoints - attack.attackPointsSpent,
      attacksUsedToday: attacker.attacksUsedToday + 1,
      totalAttacksLaunched: attacker.totalAttacksLaunched + 1,
      totalTerritoriesCaptured: attacker.totalTerritoriesCaptured + 1,
      territoriesOwned: attacker.territoriesOwned + 1,
    );

    operations.add({
      'type': 'update',
      'table': 'users',
      'data': updatedAttacker.toMap(),
      'where': 'id = ?',
      'whereArgs': [attacker.id],
    });

    // Update previous owner stats (decrease territory count)
    if (territory.ownerId != null) {
      final previousOwner = await _dbHelper.getUser(territory.ownerId!);
      if (previousOwner != null) {
        final updatedPreviousOwner = previousOwner.copyWith(
          territoriesOwned: (previousOwner.territoriesOwned - 1).clamp(0, double.infinity.toInt()),
        );

        operations.add({
          'type': 'update',
          'table': 'users',
          'data': updatedPreviousOwner.toMap(),
          'where': 'id = ?',
          'whereArgs': [previousOwner.id],
        });
      }
    }

    // Execute all operations atomically
    await _dbHelper.executeBatch(operations);
  }

  /// Process failed attack
  Future<void> _processFailedAttack({
    required Attack attack,
    required Territory territory,
    required GameUser attacker,
    required int newShieldLevel,
  }) async {
    final now = DateTime.now();
    
    final operations = <Map<String, dynamic>>[];

    // Update territory with reduced shield
    final damagedTerritory = territory.copyWith(
      currentShield: newShieldLevel,
      status: TerritoryStatus.peaceful, // Return to peaceful after failed attack
      clearAttacker: true,
    );

    operations.add({
      'type': 'update',
      'table': 'territories',
      'data': damagedTerritory.toMap(),
      'where': 'id = ?',
      'whereArgs': [territory.id],
    });

    // Insert attack record
    operations.add({
      'type': 'insert',
      'table': 'attacks',
      'data': attack.copyWith(
        status: AttackStatus.completed,
        completedAt: now,
        successful: false,
        finalShield: newShieldLevel,
      ).toMap(),
    });

    // Update attacker stats
    final updatedAttacker = attacker.copyWith(
      attackPoints: attacker.attackPoints - attack.attackPointsSpent,
      attacksUsedToday: attacker.attacksUsedToday + 1,
      totalAttacksLaunched: attacker.totalAttacksLaunched + 1,
    );

    operations.add({
      'type': 'update',
      'table': 'users',
      'data': updatedAttacker.toMap(),
      'where': 'id = ?',
      'whereArgs': [attacker.id],
    });

    // Award defense win to territory owner
    if (territory.ownerId != null) {
      final defender = await _dbHelper.getUser(territory.ownerId!);
      if (defender != null) {
        final updatedDefender = defender.copyWith(
          totalDefensesWon: defender.totalDefensesWon + 1,
        );

        operations.add({
          'type': 'update',
          'table': 'users',
          'data': updatedDefender.toMap(),
          'where': 'id = ?',
          'whereArgs': [defender.id],
        });
      }
    }

    // Execute all operations atomically
    await _dbHelper.executeBatch(operations);
  }

  /// Add shields to a territory (defending)
  /// Rule: 100 steps = +1 Shield Point when defending
  Future<bool> defendTerritory({
    required String defenderId,
    required String territoryId,
    required int shieldPoints,
  }) async {
    // Validate user exists and has enough shield points
    final defender = await _dbHelper.getUser(defenderId);
    if (defender == null || defender.shieldPoints < shieldPoints) {
      return false;
    }

    // Validate territory exists and is owned by defender
    final territory = await _dbHelper.getTerritory(territoryId);
    if (territory == null || territory.ownerId != defenderId) {
      return false;
    }

    // Calculate new shield level (capped at max)
    final newShieldLevel = (territory.currentShield + shieldPoints).clamp(0, territory.maxShield);
    
    final operations = <Map<String, dynamic>>[];

    // Update territory shields
    final reinforcedTerritory = territory.copyWith(
      currentShield: newShieldLevel,
    );

    operations.add({
      'type': 'update',
      'table': 'territories',
      'data': reinforcedTerritory.toMap(),
      'where': 'id = ?',
      'whereArgs': [territory.id],
    });

    // Spend defender's shield points
    final updatedDefender = defender.copyWith(
      shieldPoints: defender.shieldPoints - shieldPoints,
    );

    operations.add({
      'type': 'update',
      'table': 'users',
      'data': updatedDefender.toMap(),
      'where': 'id = ?',
      'whereArgs': [defender.id],
    });

    // Update any active attacks on this territory
    final activeAttack = await _dbHelper.getActiveAttackForTerritory(territoryId);
    if (activeAttack != null) {
      final updatedAttack = activeAttack.copyWith(
        shieldPointsDefended: activeAttack.shieldPointsDefended + shieldPoints,
      );

      operations.add({
        'type': 'update',
        'table': 'attacks',
        'data': updatedAttack.toMap(),
        'where': 'id = ?',
        'whereArgs': [activeAttack.id],
      });
    }

    await _dbHelper.executeBatch(operations);
    return true;
  }

  /// Get attack recommendations for a user
  Future<List<Territory>> getRecommendedTargets(String userId, {int limit = 10}) async {
    final attackableTerritories = await _dbHelper.getAttackableTerritories(userId);
    final user = await _dbHelper.getUser(userId);
    
    if (user == null) return [];

    // Sort by shield level (easier targets first) and then by name
    attackableTerritories.sort((a, b) {
      final shieldComparison = a.currentShield.compareTo(b.currentShield);
      if (shieldComparison != 0) return shieldComparison;
      return a.name.compareTo(b.name);
    });

    return attackableTerritories.take(limit).toList();
  }

  /// Calculate attack success probability
  Future<double> calculateAttackSuccessProbability({
    required String territoryId,
    required int attackPoints,
  }) async {
    final territory = await _dbHelper.getTerritory(territoryId);
    if (territory == null) return 0.0;

    final shieldHits = await _economyService.attackPointsToShieldHits(attackPoints);
    
    if (shieldHits >= territory.currentShield) {
      return 1.0; // Guaranteed success
    } else {
      return shieldHits / territory.currentShield; // Partial success probability
    }
  }

  /// Get attack history for a user
  Future<List<Attack>> getAttackHistory(String userId, {int limit = 20}) async {
    return await _dbHelper.getUserAttacks(userId);
  }

  /// Get active attacks for a user
  Future<List<Attack>> getActiveAttacks(String userId) async {
    return await _dbHelper.getUserAttacks(userId, status: AttackStatus.active);
  }

  /// Get territories under attack (for world view)
  Future<List<Map<String, dynamic>>> getTerritoriesUnderAttack() async {
    // This would be implemented with a more complex query
    // For now, we'll get all territories and filter
    final allTerritories = await _dbHelper.getAllTerritories();
    final underAttack = allTerritories
        .where((t) => t.isUnderAttack)
        .map((t) => {
          'territory': t,
          'attack': _dbHelper.getActiveAttackForTerritory(t.id),
        })
        .toList();

    return underAttack;
  }

  /// Cleanup expired cooldowns and reset daily attacks
  /// Should be called periodically (e.g., on app start)
  Future<void> performMaintenanceTasks() async {
    await _dbHelper.cleanupExpiredCooldowns();
    await _dbHelper.resetDailyAttackCounts();
  }

  /// Get battle statistics for a territory
  Future<Map<String, dynamic>> getTerritoryBattleStats(String territoryId) async {
    final territory = await _dbHelper.getTerritory(territoryId);
    if (territory == null) return {};

    // Count total attacks on this territory
    // This would need a more complex query in production
    return {
      'territory': territory,
      'total_attacks_received': 0, // Would be calculated from attacks table
      'successful_defenses': 0, // Would be calculated from attacks table
      'last_attack_date': null, // Would be calculated from attacks table
      'current_threat_level': territory.isUnderAttack ? 'HIGH' : 'LOW',
    };
  }

  /// Get leaderboard data
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 10}) async {
    // This would need more complex queries to get user rankings
    // For now, return empty list - would be implemented with proper queries
    return [];
  }
}
