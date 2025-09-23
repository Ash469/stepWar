import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import '../models/territory.dart';
import '../models/battle.dart';
import '../models/daily_activity.dart';
import '../models/game_config.dart';
import 'firestore_service.dart';
import 'persistence_service.dart';

class FirebaseGameDatabase {
  static final FirebaseGameDatabase _instance = FirebaseGameDatabase._internal();
  factory FirebaseGameDatabase() => _instance;
  FirebaseGameDatabase._internal();

  FirebaseFirestore? _firestore;
  final PersistenceService _persistence = PersistenceService();
  final Uuid _uuid = const Uuid();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialize the Game Database service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _firestore = FirebaseFirestore.instance;
      _firestore?.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      _isInitialized = true;
      
      if (kDebugMode) print('🎮 [GameDB] Game Database service initialized');
    } catch (e) {
      if (kDebugMode) print('❌ [GameDB] Failed to initialize: $e');
      throw Exception('Failed to initialize Firebase Game Database');
    }
  }

  // ==========================================================================
  // COLLECTION REFERENCES
  // ==========================================================================
  
  CollectionReference get _users => _firestore!.collection('users');
  CollectionReference get _territories => _firestore!.collection('territories');
  CollectionReference get _battles => _firestore!.collection('battles');
  CollectionReference get _dailyActivity => _firestore!.collection('daily_activity');
  CollectionReference get _config => _firestore!.collection('config');

  // ==========================================================================
  // GAME CONFIG METHODS
  // ==========================================================================

  /// Get current game configuration
  Future<GameConfig?> getGameConfig() async {
    try {
      if (kDebugMode) print('⚙️ [GameDB] Fetching game config...');
      
      final doc = await _config.doc('runtime').get();
      
      if (!doc.exists) {
        if (kDebugMode) print('⚠️ [GameDB] Config not found, creating default...');
        return await createDefaultGameConfig();
      }
      
      final data = doc.data() as Map<String, dynamic>;
      final config = GameConfig.fromFirestoreMap(data);
      
      if (kDebugMode) {
        print('✅ [GameDB] Game config loaded:');
        print('   • Steps per attack point: ${config.stepsPerAttackPoint}');
        print('   • Attack points per shield hit: ${config.attackPointsPerShieldHit}');
        print('   • Daily attack limit: ${config.dailyAttackLimit}');
        print('   • Territory cooldown: ${config.cooldownHours}h');
      }
      
      return config;
    } catch (e) {
      if (kDebugMode) print('❌ [GameDB] Error fetching game config: $e');
      return null;
    }
  }

  /// Create default game configuration
  Future<GameConfig?> createDefaultGameConfig() async {
    try {
      final config = GameConfig.defaultConfig();
      await _config.doc('runtime').set(config.toFirestoreMap());
      
      if (kDebugMode) print('✅ [GameDB] Created default game config');
      return config;
    } catch (e) {
      if (kDebugMode) print('❌ [GameDB] Error creating default config: $e');
      return null;
    }
  }

  /// Listen to game config changes
  Stream<GameConfig?> listenToGameConfig() {
    return _config.doc('runtime').snapshots().map((doc) {
      if (!doc.exists) return null;
      try {
        final data = doc.data() as Map<String, dynamic>;
        return GameConfig.fromFirestoreMap(data);
      } catch (e) {
        if (kDebugMode) print('❌ [GameDB] Error parsing config from stream: $e');
        return null;
      }
    });
  }

  // ==========================================================================
  // TERRITORY METHODS
  // ==========================================================================

  /// Get all territories
  Future<List<Territory>> getAllTerritories() async {
    try {
      if (kDebugMode) print('🌍 [GameDB] Fetching all territories...');
      
      final snapshot = await _territories.get();
      final territories = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Territory.fromFirestoreMap(data);
      }).toList();
      
      if (kDebugMode) print('✅ [GameDB] Loaded ${territories.length} territories');
      return territories;
    } catch (e) {
      if (kDebugMode) print('❌ [GameDB] Error fetching territories: $e');
      return [];
    }
  }

  /// Get a specific territory by ID
  Future<Territory?> getTerritory(String territoryId) async {
    try {
      final doc = await _territories.doc(territoryId).get();
      if (!doc.exists) return null;
      
      final data = doc.data() as Map<String, dynamic>;
      return Territory.fromFirestoreMap(data);
    } catch (e) {
      if (kDebugMode) print('❌ [GameDB] Error fetching territory $territoryId: $e');
      return null;
    }
  }

  /// Get territories owned by a user
  Future<List<Territory>> getUserTerritories(String userId) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Check cache first
      if (_persistence.areUserTerritoriesFresh(userId)) {
        final cached = await _persistence.loadUserTerritories(userId);
        if (cached.isNotEmpty) {
          if (kDebugMode) print('📖 Using cached territories for user: $userId');
          return cached;
        }
      }

      // Fetch from Firestore
      if (kDebugMode) print('🔍 Fetching territories from Firestore for user: $userId');
      
      final snapshot = await _firestore!
          .collection('territories')
          .where('owner_id', isEqualTo: userId)
          .get();
      
      final territories = snapshot.docs
          .map((doc) => Territory.fromFirestoreMap(doc.data()))
          .toList();
      
      // Cache the results
      await _persistence.saveUserTerritories(userId, territories);
      
      return territories;
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching user territories: $e');
      
      // Try to return cached data as fallback
      return await _persistence.loadUserTerritories(userId);
    }
  }

  /// Listen to all territories
  Stream<List<Territory>> listenToAllTerritories() {
    return _territories.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Territory.fromFirestoreMap(data);
      }).toList();
    });
  }

  /// Listen to territories by status
  Stream<List<Territory>> listenToTerritoriesByStatus(TerritoryStatus status) {
    return _territories
        .where('status', isEqualTo: status.toString().split('.').last)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Territory.fromFirestoreMap(data);
      }).toList();
    });
  }

  /// Listen to territories owned by a user
  Stream<List<Territory>> listenToUserTerritories(String userId) {
    if (kDebugMode) {
      print('🔍 [GameDB] Setting up stream for user territories: $userId');
      print('🎯 [GameDB] Expected user ID: ttIkh7ZY8ENdUsmVIH4h0m4DCl82');
    }
    
    return _territories
        .where('owner_id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      if (kDebugMode) {
        print('📊 [GameDB] Stream update: Found ${snapshot.docs.length} territories for user $userId');
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          print('   • ${data['name']} (owner_id: ${data['owner_id']})');
        }
      }
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Territory.fromFirestoreMap(data);
      }).toList();
    });
  }

  /// Update territory
  Future<bool> updateTerritory(Territory territory) async {
    try {
      final data = territory.toFirestoreMap();
      data['updated_at'] = FieldValue.serverTimestamp();
      
      await _territories.doc(territory.id).set(data, SetOptions(merge: true));
      
      if (kDebugMode) print('✅ [GameDB] Updated territory: ${territory.name}');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ [GameDB] Error updating territory: $e');
      return false;
    }
  }

  /// Create a new territory
  Future<Territory?> createTerritory({
    required String name,
    required int initialShield,
    required int maxShield,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final now = DateTime.now();
      final territoryId = _uuid.v4();
      
      final territory = Territory(
        id: territoryId,
        name: name,
        currentShield: initialShield,
        maxShield: maxShield,
        status: TerritoryStatus.peaceful,
        createdAt: now,
        updatedAt: now,
        latitude: latitude,
        longitude: longitude,
      );
      
      await _territories.doc(territoryId).set(territory.toFirestoreMap());
      
      if (kDebugMode) print('✅ [GameDB] Created territory: $name');
      return territory;
    } catch (e) {
      if (kDebugMode) print('❌ [GameDB] Error creating territory: $e');
      return null;
    }
  }

  // ==========================================================================
  // ATTACK & BATTLE METHODS
  // ==========================================================================

  /// Start an attack on a territory
  Future<Battle?> startAttack({
    required String attackerId,
    required String attackerNickname,
    required String territoryId,
  }) async {
    try {
      if (kDebugMode) print('⚔️ [GameDB] Starting attack on territory $territoryId...');
      
      // Get territory and validate
      final territory = await getTerritory(territoryId);
      if (territory == null) {
        if (kDebugMode) print('❌ [GameDB] Territory not found');
        return null;
      }
      
      if (!territory.canBeAttacked) {
        if (kDebugMode) print('❌ [GameDB] Territory cannot be attacked (status: ${territory.status})');
        return null;
      }

      final battleId = _uuid.v4();
      final now = DateTime.now();
      
      // Create battle record
      final battle = Battle(
        id: battleId,
        attackerId: attackerId,
        attackerNickname: attackerNickname,
        defenderId: territory.ownerId,
        defenderNickname: territory.ownerNickname,
        territoryId: territoryId,
        territoryName: territory.name,
        initialShield: territory.currentShield,
        currentShield: territory.currentShield,
        startedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      // Update territory to under attack
      final updatedTerritory = territory.copyWith(
        status: TerritoryStatus.underAttack,
        attackerId: attackerId,
        attackStarted: now,
        updatedAt: now,
      );

      // Execute both updates in a transaction
      await _firestore!.runTransaction((transaction) async {
        transaction.set(_battles.doc(battleId), battle.toFirestoreMap());
        transaction.set(_territories.doc(territoryId), updatedTerritory.toFirestoreMap());
      });

      if (kDebugMode) {
        print('✅ [GameDB] Attack started!');
        print('   • Battle ID: $battleId');
        print('   • Attacker: $attackerNickname');
        print('   • Defender: ${territory.ownerNickname ?? "None"}');
        print('   • Territory: ${territory.name}');
        print('   • Initial Shield: ${territory.currentShield}');
      }
      
      return battle;
    } catch (e) {
      if (kDebugMode) print('❌ [GameDB] Error starting attack: $e');
      return null;
    }
  }

  /// Process attack points spent by attacker
  Future<bool> processAttackPoints({
    required String battleId,
    required int attackPoints,
    required int stepsBurned,
  }) async {
    try {
      final battle = await getBattle(battleId);
      if (battle == null || !battle.isOngoing) {
        if (kDebugMode) print('❌ [GameDB] Battle not found or not ongoing');
        return false;
      }

      final territory = await getTerritory(battle.territoryId);
      if (territory == null) {
        if (kDebugMode) print('❌ [GameDB] Territory not found');
        return false;
      }

      // Calculate shield damage (10 attack points = 1 shield hit)
      final gameConfig = await getGameConfig();
      final attackPointsPerHit = gameConfig?.attackPointsPerShieldHit ?? 10;
      final shieldHits = attackPoints ~/ attackPointsPerHit;
      final newShield = (territory.currentShield - shieldHits).clamp(0, territory.maxShield);
      
      if (kDebugMode) {
        print('⚔️ [GameDB] Processing attack: $attackPoints points → $shieldHits hits → shield: ${territory.currentShield} → $newShield');
      }

      // Update battle
      final updatedBattle = battle.copyWith(
        attackPointsSpent: battle.attackPointsSpent + attackPoints,
        stepsBurnedByAttacker: battle.stepsBurnedByAttacker + stepsBurned,
        currentShield: newShield,
        updatedAt: DateTime.now(),
      );

      // Check if territory is captured
      bool territoryChanged = false;
      Territory? updatedTerritory;
      
      if (newShield <= 0) {
        // Territory captured!
        if (kDebugMode) print('🏆 [GameDB] Territory captured!');
        
        final captureConfig = gameConfig ?? GameConfig.defaultConfig();
        final cooldownUntil = DateTime.now().add(Duration(hours: captureConfig.cooldownHours));
        
        updatedTerritory = territory.copyWith(
          ownerId: battle.attackerId,
          ownerNickname: battle.attackerNickname,
          currentShield: captureConfig.baseShieldOnCapture,
          status: TerritoryStatus.cooldown,
          cooldownUntil: cooldownUntil,
          clearAttacker: true,
          updatedAt: DateTime.now(),
        );
        
        final finalBattle = updatedBattle.copyWith(
          result: BattleResult.attackerWin,
          endedAt: DateTime.now(),
          duration: updatedBattle.currentDuration,
          currentShield: captureConfig.baseShieldOnCapture,
        );
        
        territoryChanged = true;
        
        // Execute transaction
        await _firestore!.runTransaction((transaction) async {
          transaction.set(_battles.doc(battleId), finalBattle.toFirestoreMap());
          transaction.set(_territories.doc(territory.id), updatedTerritory!.toFirestoreMap());
        });
        
        // Update user stats for capture
        await _updateUserStatsOnCapture(battle.attackerId, battle.defenderId);
        
      } else {
        // Continue battle
        updatedTerritory = territory.copyWith(
          currentShield: newShield,
          updatedAt: DateTime.now(),
        );
        
        // Execute transaction
        await _firestore!.runTransaction((transaction) async {
          transaction.set(_battles.doc(battleId), updatedBattle.toFirestoreMap());
          transaction.set(_territories.doc(territory.id), updatedTerritory!.toFirestoreMap());
        });
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('❌ [GameDB] Error processing attack: $e');
      return false;
    }
  }

  /// Process shield points added by defender
  Future<bool> processDefensePoints({
    required String battleId,
    required int shieldPoints,
    required int stepsBurned,
  }) async {
    try {
      final battle = await getBattle(battleId);
      if (battle == null || !battle.isOngoing) {
        if (kDebugMode) print('❌ [GameDB] Battle not found or not ongoing');
        return false;
      }

      final territory = await getTerritory(battle.territoryId);
      if (territory == null) {
        if (kDebugMode) print('❌ [GameDB] Territory not found');
        return false;
      }

      // Add shield points (1 shield point = 1 shield)
      final newShield = (territory.currentShield + shieldPoints).clamp(0, territory.maxShield);
      
      if (kDebugMode) {
        print('🛡️ [GameDB] Processing defense: $shieldPoints points → shield: ${territory.currentShield} → $newShield');
      }

      // Update battle
      final updatedBattle = battle.copyWith(
        shieldPointsAdded: battle.shieldPointsAdded + shieldPoints,
        stepsBurnedByDefender: battle.stepsBurnedByDefender + stepsBurned,
        currentShield: newShield,
        updatedAt: DateTime.now(),
      );

      // Update territory
      final updatedTerritory = territory.copyWith(
        currentShield: newShield,
        updatedAt: DateTime.now(),
      );

      // Execute transaction
      await _firestore!.runTransaction((transaction) async {
        transaction.set(_battles.doc(battleId), updatedBattle.toFirestoreMap());
        transaction.set(_territories.doc(territory.id), updatedTerritory.toFirestoreMap());
      });

      return true;
    } catch (e) {
      if (kDebugMode) print('❌ [GameDB] Error processing defense: $e');
      return false;
    }
  }

  /// Get battle by ID
  Future<Battle?> getBattle(String battleId) async {
    try {
      final doc = await _battles.doc(battleId).get();
      if (!doc.exists) return null;
      
      final data = doc.data() as Map<String, dynamic>;
      return Battle.fromFirestoreMap(data);
    } catch (e) {
      if (kDebugMode) print('❌ [GameDB] Error fetching battle: $e');
      return null;
    }
  }

  /// Get active battles for a territory
  Future<List<Battle>> getActiveBattlesForTerritory(String territoryId) async {
    try {
      final snapshot = await _battles
          .where('territory_id', isEqualTo: territoryId)
          .where('result', isEqualTo: 'ongoing')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Battle.fromFirestoreMap(data);
      }).toList();
    } catch (e) {
      if (kDebugMode) print('❌ [GameDB] Error fetching active battles: $e');
      return [];
    }
  }

  /// Listen to battle updates
  Stream<Battle?> listenToBattle(String battleId) {
    return _battles.doc(battleId).snapshots().map((doc) {
      if (!doc.exists) return null;
      try {
        final data = doc.data() as Map<String, dynamic>;
        return Battle.fromFirestoreMap(data);
      } catch (e) {
        if (kDebugMode) print('❌ [GameDB] Error parsing battle from stream: $e');
        return null;
      }
    });
  }

  // ==========================================================================
  // DAILY ACTIVITY METHODS
  // ==========================================================================

  /// Get or create today's activity for user
  Future<DailyActivity> getTodayActivity(String userId, String userNickname) async {
    try {
      final todayId = DailyActivity.generateTodayId(userId);
      final doc = await _dailyActivity.doc(todayId).get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return DailyActivity.fromFirestoreMap(data);
      } else {
        // Create new daily activity record
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        final activity = DailyActivity(
          id: todayId,
          userId: userId,
          userNickname: userNickname,
          date: today,
          createdAt: now,
          updatedAt: now,
        );
        
        await _dailyActivity.doc(todayId).set(activity.toFirestoreMap());
        return activity;
      }
    } catch (e) {
      if (kDebugMode) print('❌ [GameDB] Error getting daily activity: $e');
      // Return default activity
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

  /// Update daily activity with steps
  Future<bool> updateDailySteps(String userId, String userNickname, int steps) async {
    try {
      final todayId = DailyActivity.generateTodayId(userId);
      final activity = await getTodayActivity(userId, userNickname);
      
      final updatedActivity = activity.copyWith(
        stepsToday: steps,
        reachedStepGoalToday: steps >= activity.stepGoal,
        updatedAt: DateTime.now(),
      );
      
      await _dailyActivity.doc(todayId).set(updatedActivity.toFirestoreMap(), SetOptions(merge: true));
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ [GameDB] Error updating daily steps: $e');
      return false;
    }
  }

  // ==========================================================================
  // HELPER METHODS
  // ==========================================================================

  /// Update user stats when territory is captured
  Future<void> _updateUserStatsOnCapture(String attackerId, String? defenderId) async {
    try {
      // Update attacker stats
      final attackerDoc = await _users.doc(attackerId).get();
      if (attackerDoc.exists) {
        final attackerData = attackerDoc.data() as Map<String, dynamic>;
        final attacker = GameUser.fromFirestoreMap(attackerData);
        
        final updatedAttacker = attacker.copyWith(
          totalTerritoriesCaptured: attacker.totalTerritoriesCaptured + 1,
          territoriesOwned: attacker.territoriesOwned + 1,
          updatedAt: DateTime.now(),
        );
        
        await _users.doc(attackerId).set(updatedAttacker.toFirestoreMap(), SetOptions(merge: true));
      }

      // Update defender stats (if they exist)
      if (defenderId != null) {
        final defenderDoc = await _users.doc(defenderId).get();
        if (defenderDoc.exists) {
          final defenderData = defenderDoc.data() as Map<String, dynamic>;
          final defender = GameUser.fromFirestoreMap(defenderData);
          
          final updatedDefender = defender.copyWith(
            territoriesOwned: (defender.territoriesOwned - 1).clamp(0, 999),
            updatedAt: DateTime.now(),
          );
          
          await _users.doc(defenderId).set(updatedDefender.toFirestoreMap(), SetOptions(merge: true));
        }
      }
      
      if (kDebugMode) print('✅ [GameDB] Updated user stats for capture');
    } catch (e) {
      if (kDebugMode) print('❌ [GameDB] Error updating user stats: $e');
    }
  }

  /// Check if a user can attack today (daily limit)
  Future<bool> canUserAttackToday(String userId) async {
    try {
      final userDoc = await _users.doc(userId).get();
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final user = GameUser.fromFirestoreMap(userData);
      
      // Check if we need to reset daily attacks
      if (user.needsAttackReset) {
        final updatedUser = user.copyWith(
          attacksUsedToday: 0,
          lastAttackReset: DateTime.now(),
        );
        await _users.doc(userId).set(updatedUser.toFirestoreMap(), SetOptions(merge: true));
        return true;
      }
      
      return user.canAttackToday;
    } catch (e) {
      if (kDebugMode) print('❌ [GameDB] Error checking attack limit: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    if (kDebugMode) print('🎮 [GameDB] Game Database service disposed');
  }
}
