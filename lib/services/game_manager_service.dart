import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/territory.dart';
import '../services/production_step_counter.dart';
import '../database/database_helper.dart';
import '../services/firestore_service.dart';
import 'step_economy_service.dart';
import 'territory_service.dart' as territory_svc;
import 'attack_service.dart' as attack_svc;
import 'user_service.dart';
import 'persistence_service.dart';
import 'auth_service.dart';

/// Central game manager that coordinates all game systems
class GameManagerService {
  static final GameManagerService _instance = GameManagerService._internal();
  factory GameManagerService() => _instance;
  GameManagerService._internal();

  final ProductionStepCounter _stepCounter = ProductionStepCounter();
  final StepEconomyService _economyService = StepEconomyService();
  final territory_svc.TerritoryService _territoryService =
      territory_svc.TerritoryService();
  final attack_svc.AttackService _attackService = attack_svc.AttackService();
  final UserService _userService = UserService();
  final PersistenceService _persistence = PersistenceService();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  // Current user session
  String? _currentUserId;
  GameUser? _currentUser;
  Timer? _stepUpdateTimer;
  Timer? _maintenanceTimer;

  // Stream controllers for real-time updates
  final StreamController<GameUser> _userUpdateController =
      StreamController<GameUser>.broadcast();
  final StreamController<List<Territory>> _territoryUpdateController =
      StreamController<List<Territory>>.broadcast();
  final StreamController<Map<String, dynamic>> _gameEventController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Public streams
  Stream<GameUser> get userUpdates => _userUpdateController.stream;
  Stream<List<Territory>> get territoryUpdates =>
      _territoryUpdateController.stream;
  Stream<Map<String, dynamic>> get gameEvents => _gameEventController.stream;

  // Getters
  String? get currentUserId => _currentUserId;
  GameUser? get currentUser => _currentUser;
  bool get isUserLoggedIn => _currentUserId != null;

  // Step conversion constants
  static const int STEPS_PER_ATTACK_POINT = 10; // 10 steps = 1 attack point
  static const int ATTACK_POINTS_PER_SHIELD =
      5; // 5 attack points = 1 shield point

  /// Initialize the game manager
  Future<bool> initialize() async {
    try {
      // Initialize persistence service
      await _persistence.initialize();

      // Load any persisted game session data
      _loadPersistedGameSession();

      // Perform maintenance tasks
      await _attackService.performMaintenanceTasks();

      // Start maintenance timer (runs every hour)
      _maintenanceTimer = Timer.periodic(const Duration(hours: 1), (timer) {
        _performPeriodicMaintenance();
      });

      if (kDebugMode) {
        print('🎮 Game Manager initialized successfully');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Game Manager initialization failed: $e');
      }
      return false;
    }
  }

  /// Login user or create new user (legacy method for nickname-based login)
  @Deprecated('Use loginUserWithFirebaseId instead')
  Future<bool> loginUser(String nickname) async {
    try {
      // Try to get existing user
      GameUser? user = await _userService.getUserByNickname(nickname);

      if (user == null) {
        // Create new user
        final userId = await _userService.createUser(nickname);
        if (userId == null) {
          return false; // Nickname might be taken or other error
        }
        user = await _userService.getUser(userId);
      }

      if (user == null) return false;

      _currentUserId = user.id;
      _currentUser = user;

      // Start step tracking integration
      await _startStepIntegration();

      // Emit initial user state
      _userUpdateController.add(user);

      // Emit initial territory state
      final territories = await _territoryService.getAllTerritories();
      _territoryUpdateController.add(territories);

      // Emit login event
      _gameEventController.add({
        'type': 'user_login',
        'user': user,
        'timestamp': DateTime.now(),
      });

      if (kDebugMode) {
        print('🎮 User logged in: ${user.nickname} (${user.id})');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ User login failed: $e');
      }
      return false;
    }
  }

  /// Login user with Firebase authentication
  Future<bool> loginUserWithFirebaseId(String firebaseUserId) async {
    try {
      final firestoreService = FirestoreService();
      await firestoreService.initialize();

      // Get user profile from Firestore
      GameUser? user = await firestoreService.getFirestoreUser(firebaseUserId);

      if (user == null) {
        if (kDebugMode) {
          print(
              '❌ User profile not found in Firestore for Firebase user: $firebaseUserId');
        }
        return false;
      }

      if (kDebugMode) {
        print(
            '✅ User profile loaded from Firestore: ${user.nickname} (ID: ${user.id})');
      }

      _currentUserId = user.id;
      _currentUser = user;

      // For new users (totalSteps == 0), establish step baseline to ensure they start fresh
      if (user.totalSteps == 0) {
        await _establishStepBaseline(user);
      }

      // Start step tracking integration
      await _startStepIntegration();

      // Emit initial user state
      _userUpdateController.add(user);

      // Emit initial territory state
      final territories = await _territoryService.getAllTerritories();
      _territoryUpdateController.add(territories);

      // Persist game session
      await _persistGameSession();

      // Emit login event
      _gameEventController.add({
        'type': 'user_login',
        'user': user,
        'timestamp': DateTime.now(),
      });

      if (kDebugMode) {
        print('🎮 Firebase user logged in: ${user.nickname} (${user.id})');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase user login failed: $e');
      }
      return false;
    }
  }

  /// Sync user data with Firebase
  Future<void> syncUserWithFirebase() async {
    if (_currentUser == null) return;

    try {
      final firestoreService = FirestoreService();
      await firestoreService.initialize();
      await firestoreService.updateFirestoreUser(_currentUser!);

      if (kDebugMode) {
        print('🔄 User data synced with Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firestore sync failed: $e');
      }
    }
  }

  /// Logout current user
  Future<void> logoutUser() async {
    _stopStepIntegration();

    if (_currentUser != null) {
      _gameEventController.add({
        'type': 'user_logout',
        'user': _currentUser,
        'timestamp': DateTime.now(),
      });
    }

    _currentUserId = null;
    _currentUser = null;

    // Clear persisted game session
    await _persistence.clearGameSession();

    if (kDebugMode) {
      print('🎮 User logged out');
    }
  }

  /// Start step tracking integration
  Future<void> _startStepIntegration() async {
    if (_currentUserId == null) return;

    // Initialize step counter if not already done
    await _stepCounter.initialize();
    await _stepCounter.startTracking();

    // Set up periodic step processing (every 30 seconds)
    _stepUpdateTimer?.cancel();
    _stepUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _processStepUpdate();
    });

    if (kDebugMode) {
      print('🚶 Step integration started for user: $_currentUserId');
    }
  }

  /// Stop step tracking integration
  void _stopStepIntegration() {
    _stepUpdateTimer?.cancel();
    _stepUpdateTimer = null;

    if (kDebugMode) {
      print('🚶 Step integration stopped');
    }
  }

  /// Process step count updates and convert to game points
  Future<void> _processStepUpdate() async {
    if (_currentUserId == null) {
      if (kDebugMode) {
        print('⚠️ _processStepUpdate skipped: currentUser is null.');
      }
      return;
    }

    try {
      // FIX: Fetch the most recent user data from Firestore before processing.
      // This prevents using a stale `_currentUser` object from memory and ensures
      // calculations are based on the source of truth.
      final freshUser = await _firestoreService.getFirestoreUser(_currentUserId!);
      if (freshUser == null) {
        if (kDebugMode) {
            print('❌ _processStepUpdate failed: Could not fetch fresh user data for $_currentUserId.');
        }
        return;
      }

      final currentDailySteps = _stepCounter.dailySteps;

      // Pass the fresh user object to the economy service.
      final updatedUser = await _economyService.processStepUpdate(freshUser, currentDailySteps);

      // Check if there are any changes to persist.
      // The user object from economy service might be different due to new steps/points.
      if (updatedUser != freshUser) {
        _currentUser = updatedUser;

        // Now, as the central manager, save the updated user state to ALL data sources.
        await _firestoreService.updateFirestoreUser(_currentUser!);
        await _authService.updateUserProfile(_currentUser!); // This updates Realtime DB
        await DatabaseHelper().updateUser(_currentUser!); // This updates local SQLite DB

        // Persist the session locally
        await _persistGameSession();

        // Notify the UI
        _userUpdateController.add(_currentUser!);

        if (kDebugMode) {
          print(
              '🚶 Steps processed & synced: daily=${_currentUser!.totalSteps}, attack=${_currentUser!.attackPoints}, shield=${_currentUser!.shieldPoints}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Step update processing failed in GameManager: $e');
      }
    }
  }


  /// Launch an attack on a territory
  Future<attack_svc.AttackResult> launchAttack({
    required String territoryId,
    required int attackPoints,
  }) async {
    if (_currentUserId == null) return attack_svc.AttackResult.userNotFound;

    final result = await _attackService.launchAttack(
      attackerId: _currentUserId!,
      territoryId: territoryId,
      attackPoints: attackPoints,
    );

    // Update cached user data
    await _refreshCurrentUser();

    // Emit territory updates
    final territories = await _territoryService.getAllTerritories();
    _territoryUpdateController.add(territories);

    // Emit attack event
    _gameEventController.add({
      'type': 'attack_launched',
      'attacker_id': _currentUserId,
      'territory_id': territoryId,
      'attack_points': attackPoints,
      'result': result.toString(),
      'timestamp': DateTime.now(),
    });

    if (kDebugMode) {
      print('⚔️ Attack launched: $result');
    }

    return result;
  }

  /// Defend a territory by adding shields
  Future<bool> defendTerritory({
    required String territoryId,
    required int shieldPoints,
  }) async {
    if (_currentUserId == null) return false;

    final success = await _attackService.defendTerritory(
      defenderId: _currentUserId!,
      territoryId: territoryId,
      shieldPoints: shieldPoints,
    );

    if (success) {
      // Update cached user data
      await _refreshCurrentUser();

      // Emit territory updates
      final territories = await _territoryService.getAllTerritories();
      _territoryUpdateController.add(territories);

      // Emit defense event
      _gameEventController.add({
        'type': 'territory_defended',
        'defender_id': _currentUserId,
        'territory_id': territoryId,
        'shield_points': shieldPoints,
        'timestamp': DateTime.now(),
      });

      if (kDebugMode) {
        print('🛡️ Territory defended successfully');
      }
    }

    return success;
  }

  /// Reinforce a territory with shields
  Future<bool> reinforceTerritory({
    required String territoryId,
    required int shieldPoints,
  }) async {
    if (_currentUserId == null) return false;

    final success = await _territoryService.reinforceTerritory(
      userId: _currentUserId!,
      territoryId: territoryId,
      shieldPointsToSpend: shieldPoints,
    );

    if (success) {
      // Update cached user data
      await _refreshCurrentUser();

      // Emit territory updates
      final territories = await _territoryService.getAllTerritories();
      _territoryUpdateController.add(territories);

      // Emit reinforcement event
      _gameEventController.add({
        'type': 'territory_reinforced',
        'user_id': _currentUserId,
        'territory_id': territoryId,
        'shield_points': shieldPoints,
        'timestamp': DateTime.now(),
      });

      if (kDebugMode) {
        print('🔧 Territory reinforced successfully');
      }
    }

    return success;
  }

  /// Get current user's territories
  Future<List<Territory>> getCurrentUserTerritories() async {
    if (_currentUserId == null) return [];
    return await _territoryService.getUserTerritories(_currentUserId!);
  }

  /// Get attackable territories for current user
  Future<List<Territory>> getAttackableTargets() async {
    if (_currentUserId == null) return [];
    return await _territoryService.getAttackableTerritories(_currentUserId!);
  }

  /// Get all territories
  Future<List<Territory>> getAllTerritories() async {
    return await _territoryService.getAllTerritories();
  }

  /// Get user recommendations
  Future<List<Map<String, dynamic>>> getUserRecommendations() async {
    if (_currentUserId == null) return [];
    return await _userService.getUserRecommendations(_currentUserId!);
  }

  /// Get current game state summary
  Future<Map<String, dynamic>> getGameStateSummary() async {
    final territoryStats = await _territoryService.getTerritoryStats();

    Map<String, dynamic> userStats = {};
    if (_currentUserId != null) {
      userStats =
          await _territoryService.getUserTerritoryStats(_currentUserId!) ?? {};
    }

    return {
      'current_user': _currentUser?.toMap(),
      'territory_stats': territoryStats,
      'user_territory_stats': userStats,
      'current_steps': _stepCounter.dailySteps,
      'session_steps': _stepCounter.sessionSteps,
      'timestamp': DateTime.now(),
    };
  }

  /// Give current user testing points for immediate gameplay (debug/testing only)
  Future<void> giveCurrentUserTestingPoints(
      {int attackPoints = 50, int shieldPoints = 50}) async {
    if (_currentUserId == null) return;

    await DatabaseHelper().giveUserTestingPoints(
      _currentUserId!,
      attackPoints: attackPoints,
      shieldPoints: shieldPoints,
    );

    // Refresh current user data
    await _refreshCurrentUser();
  }

  /// Reset current user's step count to current pedometer reading (debug/testing only)
  /// This fixes issues where stored steps don't match pedometer
  Future<void> resetCurrentUserStepCount() async {
    if (_currentUserId == null || _currentUser == null) return;

    final currentPedometerSteps = _stepCounter.dailySteps;

    final updatedUser = _currentUser!.copyWith(
      totalSteps: currentPedometerSteps,
    );

    await DatabaseHelper().updateUser(updatedUser);

    // Refresh current user data
    await _refreshCurrentUser();

    if (kDebugMode) {
      print(
          '🔄 User step count reset to current pedometer reading: $currentPedometerSteps');
    }
  }

  /// Refresh current user data
  Future<void> _refreshCurrentUser() async {
    if (_currentUserId == null) return;

    // Prioritize fetching from Firestore as the source of truth
    _currentUser = await _firestoreService.getFirestoreUser(_currentUserId!);
    if (_currentUser != null) {
      _userUpdateController.add(_currentUser!);
    } else {
       // Fallback to other service if needed
      _currentUser = await _userService.getUser(_currentUserId!);
       if (_currentUser != null) {
        _userUpdateController.add(_currentUser!);
      }
    }
  }


  /// Convert steps to attack points
  Future<int> convertStepsToAttackPoints(
      String userId, int stepsToConvert) async {
    try {
      if (stepsToConvert < STEPS_PER_ATTACK_POINT) return 0;

      final attackPoints = stepsToConvert ~/ STEPS_PER_ATTACK_POINT;
      final stepsUsed = attackPoints * STEPS_PER_ATTACK_POINT;

      // Update both databases
      await Future.wait([
        _firestoreService.updateUserPoints(
          userId,
          attackPoints: attackPoints,
          stepsUsed: stepsUsed,
        ),
        _authService.updateUserPoints(
          userId,
          attackPoints: attackPoints,
          stepsUsed: stepsUsed,
        )
      ]);

      if (kDebugMode) {
        print('✅ Converted $stepsUsed steps to $attackPoints attack points');
      }

      return attackPoints;
    } catch (e) {
      if (kDebugMode) print('❌ Failed to convert steps to attack points: $e');
      return 0;
    }
  }

  /// Convert attack points to shield points and update both databases
  Future<int> convertAttackPointsToShield(
      String userId, int attackPointsToConvert) async {
    try {
      if (attackPointsToConvert < ATTACK_POINTS_PER_SHIELD) return 0;

      final shieldPoints = attackPointsToConvert ~/ ATTACK_POINTS_PER_SHIELD;
      final attackPointsUsed = shieldPoints * ATTACK_POINTS_PER_SHIELD;

      // Update Firestore
      final firestoreSuccess = await _firestoreService.updateUserPoints(
        userId,
        attackPoints: -attackPointsUsed,
        shieldPoints: shieldPoints,
      );

      // Update Realtime Database
      final rtdbSuccess = await _authService.updateUserPoints(
        userId,
        attackPoints: -attackPointsUsed,
        shieldPoints: shieldPoints,
      );

      if (kDebugMode) {
        print('🔄 Points conversion results:');
        print(
            '   • Firestore update: ${firestoreSuccess ? 'Success' : 'Failed'}');
        print('   • RTDB update: ${rtdbSuccess ? 'Success' : 'Failed'}');
      }

      return shieldPoints;
    } catch (e) {
      if (kDebugMode) print('❌ Failed to convert attack points to shield: $e');
      return 0;
    }
  }

  /// Perform periodic maintenance tasks
  Future<void> _performPeriodicMaintenance() async {
    try {
      await _attackService.performMaintenanceTasks();

      // Emit updated territories after maintenance
      final territories = await _territoryService.getAllTerritories();
      _territoryUpdateController.add(territories);

      if (kDebugMode) {
        print('🔧 Periodic maintenance completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Maintenance failed: $e');
      }
    }
  }

  /// Force sync step count with game points
  Future<void> syncStepsWithGame() async {
    if (_currentUserId == null) return;

    await _processStepUpdate();

    if (kDebugMode) {
      print('🔄 Step sync completed');
    }
  }

  /// Get live step count
  int getCurrentStepCount() {
    return _stepCounter.dailySteps;
  }

  /// Get session step count
  int getSessionStepCount() {
    return _stepCounter.sessionSteps;
  }

  /// Get current user
  Future<GameUser?> getCurrentUser() async {
    if (_currentUser == null) {
      await _refreshCurrentUser();
    }
    return _currentUser;
  }

  // MARK: - Persistence Methods

  /// Load persisted game session data
  void _loadPersistedGameSession() {
    try {
      final gameData = _persistence.loadGameSession();
      final wasGameActive = gameData['isGameActive'] as bool;
      final currentUserId = gameData['currentUserId'] as String?;
      final currentUser = gameData['currentUser'] as GameUser?;

      if (wasGameActive && currentUserId != null && currentUser != null) {
        _currentUserId = currentUserId;
        _currentUser = currentUser;
        if (kDebugMode)
          print('📖 Restored game session for user: ${currentUser.nickname}');
      } else {
        if (kDebugMode) print('📖 No valid game session found');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to load persisted game session: $e');
    }
  }

  /// Persist current game session data
  Future<void> _persistGameSession() async {
    try {
      await _persistence.saveGameSession(
        isGameActive: _currentUserId != null,
        currentUserId: _currentUserId,
        currentUser: _currentUser,
        lastStepCount: _stepCounter.dailySteps,
        lastSyncTime: DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) print('❌ Failed to persist game session: $e');
    }
  }

  /// Establish step baseline for new users to ensure they start with 0 game steps
  /// This prevents new users from getting credit for steps taken before registration
  Future<void> _establishStepBaseline(GameUser user) async {
    try {
      // Initialize step counter to get current device step count
      await _stepCounter.initialize();

      // Get current pedometer reading - this becomes the baseline
      final currentDeviceSteps = _stepCounter.dailySteps;

      // Store this baseline in Firestore for this user
      final firestoreService = FirestoreService();
      await firestoreService.initialize();

      final updatedUser = user.copyWith(
        totalSteps: 0, // Reset to 0 for new users
        updatedAt: DateTime.now(),
      );

      await firestoreService.updateFirestoreUser(updatedUser);

      // Update the current user reference
      _currentUser = updatedUser;

      if (kDebugMode) {
        print(
            '📍 Step baseline established for new user ${user.nickname}: $currentDeviceSteps steps');
        print(
            '   Only steps taken after this point will count towards game progress');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to establish step baseline: $e');
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _stepUpdateTimer?.cancel();
    _maintenanceTimer?.cancel();
    _userUpdateController.close();
    _territoryUpdateController.close();
    _gameEventController.close();
    _stepCounter.dispose();

    if (kDebugMode) {
      print('🎮 Game Manager disposed');
    }
  }
}
