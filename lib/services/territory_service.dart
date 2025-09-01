import '../database/database_helper.dart';
import '../models/territory.dart';
import '../models/user.dart';
import 'step_economy_service.dart';

class TerritoryService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final StepEconomyService _economyService = StepEconomyService();

  /// Get all territories with current status
  Future<List<Territory>> getAllTerritories() async {
    await _cleanupExpiredCooldowns();
    return await _dbHelper.getAllTerritories();
  }

  /// Get territories owned by a specific user
  Future<List<Territory>> getUserTerritories(String userId) async {
    await _cleanupExpiredCooldowns();
    return await _dbHelper.getUserTerritories(userId);
  }

  /// Get a specific territory by ID
  Future<Territory?> getTerritory(String territoryId) async {
    await _cleanupExpiredCooldowns();
    return await _dbHelper.getTerritory(territoryId);
  }

  /// Get territories that can be attacked by a user
  Future<List<Territory>> getAttackableTerritories(String userId) async {
    await _cleanupExpiredCooldowns();
    return await _dbHelper.getAttackableTerritories(userId);
  }

  /// Get unowned territories
  Future<List<Territory>> getUnownedTerritories() async {
    await _cleanupExpiredCooldowns();
    final allTerritories = await _dbHelper.getAllTerritories();
    return allTerritories.where((t) => !t.isOwned).toList();
  }

  /// Get territories currently under attack
  Future<List<Territory>> getTerritoriesUnderAttack() async {
    await _cleanupExpiredCooldowns();
    final allTerritories = await _dbHelper.getAllTerritories();
    return allTerritories.where((t) => t.isUnderAttack).toList();
  }

  /// Get territories in cooldown
  Future<List<Territory>> getTerritoriesInCooldown() async {
    await _cleanupExpiredCooldowns();
    final allTerritories = await _dbHelper.getAllTerritories();
    return allTerritories.where((t) => t.isInCooldown && !t.isCooldownExpired).toList();
  }

  /// Get territory statistics
  Future<Map<String, dynamic>> getTerritoryStats() async {
    await _cleanupExpiredCooldowns();
    
    final totalTerritories = await _dbHelper.getTotalTerritories();
    final ownedCount = await _dbHelper.getOwnedTerritoryCount();
    final unownedCount = totalTerritories - ownedCount;
    
    final allTerritories = await _dbHelper.getAllTerritories();
    final underAttackCount = allTerritories.where((t) => t.isUnderAttack).length;
    final cooldownCount = allTerritories.where((t) => t.isInCooldown && !t.isCooldownExpired).length;

    return {
      'total_territories': totalTerritories,
      'owned_territories': ownedCount,
      'unowned_territories': unownedCount,
      'territories_under_attack': underAttackCount,
      'territories_in_cooldown': cooldownCount,
      'peaceful_territories': totalTerritories - underAttackCount - cooldownCount,
    };
  }

  /// Get user territory statistics
  Future<Map<String, dynamic>> getUserTerritoryStats(String userId) async {
    await _cleanupExpiredCooldowns();
    
    final userTerritories = await getUserTerritories(userId);
    final totalShields = userTerritories.fold<int>(0, (sum, t) => sum + t.currentShield);
    final maxPossibleShields = userTerritories.fold<int>(0, (sum, t) => sum + t.maxShield);
    
    final underAttack = userTerritories.where((t) => t.isUnderAttack).length;
    final inCooldown = userTerritories.where((t) => t.isInCooldown && !t.isCooldownExpired).length;

    return {
      'territories_owned': userTerritories.length,
      'total_shield_points': totalShields,
      'max_shield_capacity': maxPossibleShields,
      'shield_efficiency': maxPossibleShields > 0 ? totalShields / maxPossibleShields : 0.0,
      'territories_under_attack': underAttack,
      'territories_in_cooldown': inCooldown,
      'territories_vulnerable': userTerritories.length - underAttack - inCooldown,
    };
  }

  /// Get nearby territories (for map-based features)
  Future<List<Territory>> getNearbyTerritories({
    required double latitude,
    required double longitude,
    double radiusKm = 50.0,
  }) async {
    // This is a placeholder implementation
    // In a real app, you'd calculate distances using geographic coordinates
    final allTerritories = await getAllTerritories();
    
    return allTerritories.where((territory) {
      if (territory.latitude == null || territory.longitude == null) return false;
      
      // Simplified distance calculation (would use proper Haversine formula in production)
      final latDiff = (territory.latitude! - latitude).abs();
      final lngDiff = (territory.longitude! - longitude).abs();
      final approxDistanceKm = (latDiff + lngDiff) * 111; // Rough km conversion
      
      return approxDistanceKm <= radiusKm;
    }).toList();
  }

  /// Reinforce territory shields (spend shield points to add shields)
  Future<bool> reinforceTerritory({
    required String userId,
    required String territoryId,
    required int shieldPointsToSpend,
  }) async {
    final territory = await _dbHelper.getTerritory(territoryId);
    final user = await _dbHelper.getUser(userId);

    if (territory == null || user == null) return false;
    
    // Verify user owns the territory
    if (territory.ownerId != userId) return false;
    
    // Check if user has enough shield points
    if (user.shieldPoints < shieldPointsToSpend) return false;

    // Calculate new shield level (capped at max)
    final newShieldLevel = (territory.currentShield + shieldPointsToSpend)
        .clamp(0, territory.maxShield);
    
    if (newShieldLevel == territory.currentShield) {
      // No change possible (already at max)
      return false;
    }

    // Calculate actual shield points used (in case we hit the max)
    final actualShieldPointsUsed = newShieldLevel - territory.currentShield;

    // Update territory
    final updatedTerritory = territory.copyWith(
      currentShield: newShieldLevel,
    );
    
    // Update user
    final updatedUser = user.copyWith(
      shieldPoints: user.shieldPoints - actualShieldPointsUsed,
    );

    // Execute updates
    await _dbHelper.updateTerritory(updatedTerritory);
    await _dbHelper.updateUser(updatedUser);

    return true;
  }

  /// Get reinforcement cost for a territory
  Future<Map<String, dynamic>> getReinforcementCost({
    required String territoryId,
    required int shieldPointsWanted,
  }) async {
    final territory = await _dbHelper.getTerritory(territoryId);
    if (territory == null) {
      return {
        'error': 'Territory not found',
        'can_reinforce': false,
      };
    }

    final maxPossibleIncrease = territory.maxShield - territory.currentShield;
    final actualIncrease = shieldPointsWanted.clamp(0, maxPossibleIncrease);
    
    final costBreakdown = await _economyService.getDefenseCostBreakdown(actualIncrease);

    return {
      'territory_id': territoryId,
      'current_shield': territory.currentShield,
      'max_shield': territory.maxShield,
      'shield_points_wanted': shieldPointsWanted,
      'actual_shield_increase': actualIncrease,
      'shield_after_reinforcement': territory.currentShield + actualIncrease,
      'can_reinforce': actualIncrease > 0,
      'cost_breakdown': costBreakdown,
    };
  }

  /// Get territory recommendations for new users
  Future<List<Territory>> getRecommendedTerritoriesForNewUser() async {
    final unownedTerritories = await getUnownedTerritories();
    
    // Sort by shield level (easier targets first)
    unownedTerritories.sort((a, b) => a.currentShield.compareTo(b.currentShield));
    
    return unownedTerritories.take(5).toList();
  }

  /// Get territory value assessment
  Future<Map<String, dynamic>> assessTerritoryValue(String territoryId) async {
    final territory = await _dbHelper.getTerritory(territoryId);
    if (territory == null) return {};

    // Calculate various value metrics
    final shieldEfficiency = territory.currentShield / territory.maxShield;
    final attackCost = await _economyService.stepsNeededForShieldHits(territory.currentShield);
    
    String difficulty;
    if (territory.currentShield <= 2) {
      difficulty = 'Easy';
    } else if (territory.currentShield <= 5) {
      difficulty = 'Medium';
    } else {
      difficulty = 'Hard';
    }

    String strategicValue;
    if (territory.name.contains('New York') || territory.name.contains('London') || territory.name.contains('Tokyo')) {
      strategicValue = 'High';
    } else if (territory.name.contains('Paris') || territory.name.contains('Sydney') || territory.name.contains('Dubai')) {
      strategicValue = 'Medium';
    } else {
      strategicValue = 'Standard';
    }

    return {
      'territory': territory,
      'shield_efficiency': shieldEfficiency,
      'attack_cost_steps': attackCost,
      'difficulty': difficulty,
      'strategic_value': strategicValue,
      'is_profitable_target': attackCost <= 2000, // Arbitrary threshold
    };
  }

  /// Clean up expired cooldowns
  Future<void> _cleanupExpiredCooldowns() async {
    await _dbHelper.cleanupExpiredCooldowns();
  }

  /// Get territory ownership history (placeholder for future implementation)
  Future<List<Map<String, dynamic>>> getTerritoryHistory(String territoryId) async {
    // This would require an additional history/changelog table
    // For now, return empty list
    return [];
  }

  /// Get most contested territories
  Future<List<Map<String, dynamic>>> getMostContestedTerritories({int limit = 10}) async {
    // This would require complex queries on the attacks table
    // For now, return territories that are currently under attack or recently changed hands
    final underAttack = await getTerritoriesUnderAttack();
    
    return underAttack.map((territory) => {
      'territory': territory,
      'contest_level': 'High',
      'reason': 'Currently under attack',
    }).take(limit).toList();
  }

  /// Get territory leaderboard (most valuable territories)
  Future<List<Map<String, dynamic>>> getTerritoryLeaderboard({int limit = 10}) async {
    final allTerritories = await getAllTerritories();
    
    // Sort by a combination of factors: shield capacity, strategic value, etc.
    allTerritories.sort((a, b) {
      final aScore = (a.maxShield * 2) + (a.currentShield);
      final bScore = (b.maxShield * 2) + (b.currentShield);
      return bScore.compareTo(aScore);
    });

    return allTerritories.take(limit).map((territory) => {
      'territory': territory,
      'score': (territory.maxShield * 2) + (territory.currentShield),
      'owner': territory.ownerNickname ?? 'Unowned',
    }).toList();
  }
}
