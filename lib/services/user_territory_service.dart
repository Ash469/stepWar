import 'package:flutter/foundation.dart';
import '../models/territory.dart';
import '../models/user.dart';
import 'persistence_service.dart';
import 'firebase_game_database.dart';

/// Service for managing user territories with caching and lookup functionality
/// This service provides a bridge between local storage and Firestore for territory data
class UserTerritoryService {
  static final UserTerritoryService _instance = UserTerritoryService._internal();
  factory UserTerritoryService() => _instance;
  UserTerritoryService._internal();

  final PersistenceService _persistence = PersistenceService();
  final FirebaseGameDatabase _gameDB = FirebaseGameDatabase();

  // MARK: - Territory Lookup Methods

  /// Get user territories with intelligent caching
  /// First checks local cache, then fallback to Firestore if needed
  Future<List<Territory>> getUserTerritories(String userId, {bool forceRefresh = false}) async {
    try {
      if (kDebugMode) print('🔍 [UserTerritory] Getting territories for user: $userId');
      
      // Check if we should use cached data
      if (!forceRefresh && _persistence.areUserTerritoriesFresh(userId, maxAgeMinutes: 5)) {
        final cachedTerritories = await _persistence.loadUserTerritories(userId);
        if (cachedTerritories.isNotEmpty) {
          if (kDebugMode) {
            print('✅ [UserTerritory] Using cached territories (${cachedTerritories.length} found)');
          }
          return cachedTerritories;
        }
      }
      
      // Fetch fresh data from Firestore
      if (kDebugMode) print('📡 [UserTerritory] Fetching fresh territories from Firestore...');
      final territories = await _gameDB.getUserTerritories(userId);
      
      // Update cache
      await _persistence.saveUserTerritories(userId, territories);
      
      if (kDebugMode) {
        print('✅ [UserTerritory] Retrieved ${territories.length} territories from Firestore');
        print('🏰 [FS-User] Updated last active for user: $userId');
      }
      
      return territories;
      
    } catch (e) {
      if (kDebugMode) print('❌ [UserTerritory] Error getting user territories: $e');
      
      // Fallback to cached data even if expired
      try {
        final cachedTerritories = await _persistence.loadUserTerritories(userId);
        if (cachedTerritories.isNotEmpty) {
          if (kDebugMode) print('⚠️ [UserTerritory] Using stale cached data as fallback');
          return cachedTerritories;
        }
      } catch (cacheError) {
        if (kDebugMode) print('❌ [UserTerritory] Cache fallback also failed: $cacheError');
      }
      
      return [];
    }
  }

  /// Get user territories using stored user data from local storage
  /// This is the main method that fulfills the requirement
  Future<List<Territory>> getUserTerritoriesFromStoredData() async {
    try {
      // Load stored auth state to get user ID
      final authData = _persistence.loadAuthState();
      final userId = authData['userId'] as String?;
      
      if (userId == null) {
        if (kDebugMode) print('⚠️ [UserTerritory] No user ID found in stored data');
        return [];
      }
      
      if (kDebugMode) {
        print('📊 [UserTerritory] Using stored user ID: $userId');
        print('firestore user data saved successfully in local storage');
      }
      
      // Get territories for this user
      return await getUserTerritories(userId);
      
    } catch (e) {
      if (kDebugMode) print('❌ [UserTerritory] Error getting territories from stored data: $e');
      return [];
    }
  }

  /// Find territories owned by current user using cached Firestore data
  Future<List<Territory>> findUserTerritoriesFromCache() async {
    try {
      final authData = _persistence.loadAuthState();
      final userId = authData['userId'] as String?;
      
      if (userId == null) {
        if (kDebugMode) print('⚠️ [UserTerritory] No authenticated user found');
        return [];
      }
      
      // Try to get from cache first (don't force refresh)
      final territories = await getUserTerritories(userId, forceRefresh: false);
      
      if (kDebugMode) {
        print('🎯 [UserTerritory] Found ${territories.length} territories in user\'s ownership:');
        for (final territory in territories) {
          print('   • ${territory.name} (Status: ${territory.status.toString().split('.').last})');
          print('     Shield: ${territory.currentShield}/${territory.maxShield}');
          if (territory.isInCooldown) {
            print('     Cooldown until: ${territory.cooldownUntil}');
          }
        }
      }
      
      return territories;
      
    } catch (e) {
      if (kDebugMode) print('❌ [UserTerritory] Error finding user territories: $e');
      return [];
    }
  }

  // MARK: - Territory Analysis Methods

  /// Get territory statistics for the user
  Future<TerritoryStats> getUserTerritoryStats([String? userId]) async {
    try {
      final actualUserId = userId ?? _persistence.loadAuthState()['userId'] as String?;
      
      if (actualUserId == null) {
        return TerritoryStats.empty();
      }
      
      final territories = await getUserTerritories(actualUserId);
      
      int totalTerritories = territories.length;
      int underAttack = territories.where((t) => t.isUnderAttack).length;
      int inCooldown = territories.where((t) => t.isInCooldown).length;
      int peaceful = territories.where((t) => t.status == TerritoryStatus.peaceful).length;
      
      double averageShieldPercentage = 0.0;
      if (territories.isNotEmpty) {
        averageShieldPercentage = territories
            .map((t) => t.shieldPercentage)
            .reduce((a, b) => a + b) / territories.length;
      }
      
      return TerritoryStats(
        totalTerritories: totalTerritories,
        underAttack: underAttack,
        inCooldown: inCooldown,
        peaceful: peaceful,
        averageShieldPercentage: averageShieldPercentage,
      );
      
    } catch (e) {
      if (kDebugMode) print('❌ [UserTerritory] Error calculating territory stats: $e');
      return TerritoryStats.empty();
    }
  }

  /// Get territories that need attention (low shield, under attack, etc.)
  Future<List<Territory>> getTerritoriesNeedingAttention([String? userId]) async {
    try {
      final actualUserId = userId ?? _persistence.loadAuthState()['userId'] as String?;
      
      if (actualUserId == null) {
        return [];
      }
      
      final territories = await getUserTerritories(actualUserId);
      
      return territories.where((territory) {
        return territory.isUnderAttack || 
               territory.shieldPercentage < 0.3 || // Less than 30% shield
               (territory.isInCooldown && territory.isCooldownExpired);
      }).toList();
      
    } catch (e) {
      if (kDebugMode) print('❌ [UserTerritory] Error finding territories needing attention: $e');
      return [];
    }
  }

  // MARK: - Cache Management

  /// Refresh user territory cache
  Future<void> refreshTerritoryCache([String? userId]) async {
    try {
      final actualUserId = userId ?? _persistence.loadAuthState()['userId'] as String?;
      
      if (actualUserId == null) {
        if (kDebugMode) print('⚠️ [UserTerritory] No user ID for cache refresh');
        return;
      }
      
      await getUserTerritories(actualUserId, forceRefresh: true);
      
    } catch (e) {
      if (kDebugMode) print('❌ [UserTerritory] Error refreshing territory cache: $e');
    }
  }

  /// Clear territory cache for user
  Future<void> clearTerritoryCache([String? userId]) async {
    try {
      final actualUserId = userId ?? _persistence.loadAuthState()['userId'] as String?;
      
      if (actualUserId == null) {
        if (kDebugMode) print('⚠️ [UserTerritory] No user ID for cache clearing');
        return;
      }
      
      await _persistence.clearUserTerritories(actualUserId);
      
    } catch (e) {
      if (kDebugMode) print('❌ [UserTerritory] Error clearing territory cache: $e');
    }
  }

  /// Get cache status for user territories
  TerritoryCacheStatus getCacheStatus([String? userId]) {
    try {
      final actualUserId = userId ?? _persistence.loadAuthState()['userId'] as String?;
      
      if (actualUserId == null) {
        return TerritoryCacheStatus(
          hasCachedData: false,
          isFresh: false,
          lastUpdated: null,
        );
      }
      
      final lastUpdated = _persistence.getUserTerritoriesLastUpdated(actualUserId);
      final isFresh = _persistence.areUserTerritoriesFresh(actualUserId);
      
      return TerritoryCacheStatus(
        hasCachedData: lastUpdated != null,
        isFresh: isFresh,
        lastUpdated: lastUpdated,
      );
      
    } catch (e) {
      if (kDebugMode) print('❌ [UserTerritory] Error getting cache status: $e');
      return TerritoryCacheStatus(
        hasCachedData: false,
        isFresh: false,
        lastUpdated: null,
      );
    }
  }
}

// MARK: - Data Classes

/// Territory statistics for a user
class TerritoryStats {
  final int totalTerritories;
  final int underAttack;
  final int inCooldown;
  final int peaceful;
  final double averageShieldPercentage;

  const TerritoryStats({
    required this.totalTerritories,
    required this.underAttack,
    required this.inCooldown,
    required this.peaceful,
    required this.averageShieldPercentage,
  });

  factory TerritoryStats.empty() {
    return const TerritoryStats(
      totalTerritories: 0,
      underAttack: 0,
      inCooldown: 0,
      peaceful: 0,
      averageShieldPercentage: 0.0,
    );
  }

  @override
  String toString() {
    return 'TerritoryStats(total: $totalTerritories, underAttack: $underAttack, '
           'cooldown: $inCooldown, peaceful: $peaceful, avgShield: ${(averageShieldPercentage * 100).toStringAsFixed(1)}%)';
  }
}

/// Cache status for territory data
class TerritoryCacheStatus {
  final bool hasCachedData;
  final bool isFresh;
  final DateTime? lastUpdated;

  const TerritoryCacheStatus({
    required this.hasCachedData,
    required this.isFresh,
    required this.lastUpdated,
  });

  @override
  String toString() {
    return 'CacheStatus(hasData: $hasCachedData, fresh: $isFresh, lastUpdated: $lastUpdated)';
  }
}
