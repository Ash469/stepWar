import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/territory.dart';
import '../services/production_step_counter.dart';
import '../database/database_helper.dart';
import 'step_economy_service.dart';
import 'territory_service.dart';
import 'attack_service.dart';
import 'user_service.dart';

/// Central game manager that coordinates all game systems
class GameManagerService {
  static final GameManagerService _instance = GameManagerService._internal();
  factory GameManagerService() => _instance;
  GameManagerService._internal();

  final ProductionStepCounter _stepCounter = ProductionStepCounter();
  final StepEconomyService _economyService = StepEconomyService();
  final TerritoryService _territoryService = TerritoryService();
  final AttackService _attackService = AttackService();
  final UserService _userService = UserService();

  // Current user session
  String? _currentUserId;
  GameUser? _currentUser;
  Timer? _stepUpdateTimer;
  Timer? _maintenanceTimer;

  // Stream controllers for real-time updates
  final StreamController<GameUser> _userUpdateController = StreamController<GameUser>.broadcast();
  final StreamController<List<Territory>> _territoryUpdateController = StreamController<List<Territory>>.broadcast();
  final StreamController<Map<String, dynamic>> _gameEventController = StreamController<Map<String, dynamic>>.broadcast();

  // Public streams
  Stream<GameUser> get userUpdates => _userUpdateController.stream;
  Stream<List<Territory>> get territoryUpdates => _territoryUpdateController.stream;
  Stream<Map<String, dynamic>> get gameEvents => _gameEventController.stream;

  // Getters
  String? get currentUserId => _currentUserId;
  GameUser? get currentUser => _currentUser;
  bool get isUserLoggedIn => _currentUserId != null;

  /// Initialize the game manager
  Future<bool> initialize() async {
    try {
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

  /// Login user or create new user
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
    if (_currentUserId == null) return;

    try {
      final currentSteps = _stepCounter.totalSteps;
      final updatedUser = await _economyService.processStepUpdate(_currentUserId!, currentSteps);
      
      // Update cached user
      _currentUser = updatedUser;
      
      // Emit user update
      _userUpdateController.add(updatedUser);

      if (kDebugMode) {
        print('🚶 Steps updated: $currentSteps → ${updatedUser.attackPoints} attack points, ${updatedUser.shieldPoints} shield points');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Step update failed: $e');
      }
    }
  }

  /// Launch an attack on a territory
  Future<AttackResult> launchAttack({
    required String territoryId,
    required int attackPoints,
  }) async {
    if (_currentUserId == null) return AttackResult.userNotFound;

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
      userStats = await _territoryService.getUserTerritoryStats(_currentUserId!) ?? {};
    }

    return {
      'current_user': _currentUser?.toMap(),
      'territory_stats': territoryStats,
      'user_territory_stats': userStats,
      'current_steps': _stepCounter.totalSteps,
      'session_steps': _stepCounter.sessionSteps,
      'timestamp': DateTime.now(),
    };
  }
  
  /// Give current user testing points for immediate gameplay (debug/testing only)
  Future<void> giveCurrentUserTestingPoints({int attackPoints = 50, int shieldPoints = 50}) async {
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
    
    final currentPedometerSteps = _stepCounter.totalSteps;
    
    final updatedUser = _currentUser!.copyWith(
      totalSteps: currentPedometerSteps,
    );
    
    await DatabaseHelper().updateUser(updatedUser);
    
    // Refresh current user data
    await _refreshCurrentUser();
    
    if (kDebugMode) {
      print('🔄 User step count reset to current pedometer reading: $currentPedometerSteps');
    }
  }

  /// Refresh current user data
  Future<void> _refreshCurrentUser() async {
    if (_currentUserId == null) return;
    
    _currentUser = await _userService.getUser(_currentUserId!);
    if (_currentUser != null) {
      _userUpdateController.add(_currentUser!);
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
    return _stepCounter.totalSteps;
  }

  /// Get session step count
  int getSessionStepCount() {
    return _stepCounter.sessionSteps;
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
