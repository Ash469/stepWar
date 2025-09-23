import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';
import '../models/territory.dart';
import '../services/game_manager_service.dart';
import '../services/persistence_service.dart';
import '../services/firebase_game_database.dart';
import '../services/territory_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/step_tracking_service.dart';
import 'dart:async';

class GameProvider extends ChangeNotifier {
  final GameManagerService _gameManager = GameManagerService();
  final PersistenceService _persistence = PersistenceService();
  final FirebaseGameDatabase _firebaseDB = FirebaseGameDatabase();
  final TerritoryService _territoryService = TerritoryService();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final StepTrackingService _stepService = StepTrackingService();

  bool _isGameInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;
  GameUser? _currentUser;
  List<Territory> _territories = [];
  List<Territory> _userTerritories = [];
  StreamSubscription<List<Territory>>? _territoriesSubscription;
  StreamSubscription<List<Territory>>? _userTerritoriesSubscription;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  bool get isGameInitialized => _isGameInitialized;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  GameUser? get currentUser => _currentUser;
  List<Territory> get territories => _territories;
  List<Territory> get userTerritories => _userTerritories;
  bool get isUserLoggedIn => _gameManager.isUserLoggedIn;
  int get currentStepCount => _gameManager.getCurrentStepCount();
  int get sessionStepCount => _gameManager.getSessionStepCount();

  GameProvider() {
    _initialize();
  }
  /// Initialize the game provider
  Future<void> _initialize() async {
    _setLoading(true);
    try {
      await _persistence.initialize();
      await _firebaseDB.initialize();
      _loadPersistedGameSession();
      _isGameInitialized = await _gameManager.initialize();
      if (_isGameInitialized) {
        _territoriesSubscription = _firebaseDB.listenToAllTerritories().listen(
              _onTerritoryUpdate,
              onError: (error) {
                _setError('Failed to load territories: $error');
              },
            );
        _gameManager.userUpdates.listen(_onUserUpdate);
        _gameManager.gameEvents.listen(_onGameEvent);
        await _restoreGameSessionIfNeeded();
      }
    } catch (e) {
      _setError('Failed to initialize game: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Start game session with Firebase authenticated user
  Future<bool> startGameSession(String firebaseUserId) async {
    _setLoading(true);
    _clearError();
    try {
      final success =
          await _gameManager.loginUserWithFirebaseId(firebaseUserId);
      if (success) {
        await _loadInitialGameData();
        await _persistGameSession();
        if (kDebugMode) {
          print('🎮 Game session started for user: $firebaseUserId');
        }
      }

      return success;
    } catch (e) {
      _setError('Failed to start game session: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Load initial game data
  Future<void> _loadInitialGameData() async {
    try {
      _territories = await _gameManager.getAllTerritories();
      _userTerritories = await _gameManager.getCurrentUserTerritories();
      await _persistGameSession();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to load initial game data: $e');
      }
    }
  }

  /// Defend a territory
  Future<bool> defendTerritory(String territoryId, int shieldPoints) async {
    _setLoading(true);
    _clearError();
    try {
      final success = await _gameManager.defendTerritory(
        territoryId: territoryId,
        shieldPoints: shieldPoints,
      );
      if (success) {
        _userTerritories = await _gameManager.getCurrentUserTerritories();
        await _persistGameSession();
      }
      return success;
    } catch (e) {
      _setError('Defense failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Reinforce a territory
  Future<bool> reinforceTerritory(String territoryId, int shieldPoints) async {
    _setLoading(true);
    _clearError();
    try {
      final success = await _gameManager.reinforceTerritory(
        territoryId: territoryId,
        shieldPoints: shieldPoints,
      );
      if (success) {
        _userTerritories = await _gameManager.getCurrentUserTerritories();
        await _persistGameSession();
      }

      return success;
    } catch (e) {
      _setError('Reinforcement failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get attackable targets for the current user
  Future<List<Territory>> getAttackableTargets() async {
    try {
      return await _gameManager.getAttackableTargets();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to get attackable targets: $e');
      }
      return [];
    }
  }

  /// Get user recommendations
  Future<List<Map<String, dynamic>>> getUserRecommendations() async {
    try {
      return await _gameManager.getUserRecommendations();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to get user recommendations: $e');
      }
      return [];
    }
  }

  /// Get game state summary
  Future<Map<String, dynamic>> getGameStateSummary() async {
    try {
      return await _gameManager.getGameStateSummary();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to get game state summary: $e');
      }
      return {};
    }
  }

  /// Sync steps with game (force update)
  Future<void> syncStepsWithGame() async {
    try {
      await _gameManager.syncStepsWithGame();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to sync steps: $e');
      }
    }
  }

  /// Sync user data with Firebase
  Future<void> syncUserWithFirebase() async {
    try {
      await _gameManager.syncUserWithFirebase();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to sync with Firebase: $e');
      }
    }
  }

  /// Convert steps to attack points
  Future<bool> convertStepsToPoints(int stepsToConvert) async {
    _setLoading(true);
    _clearError();
    try {
      if (currentUser == null) {
        _setError("User not logged in.");
        return false;
      }

      final availableSteps = _stepService.dailySteps;
      if (stepsToConvert > availableSteps) {
        _setError("Not enough steps to convert.");
        return false;
      }

      // Calculate points (10 steps = 1 attack point)
      final attackPointsGained = stepsToConvert ~/ 10;
      if (attackPointsGained == 0) {
        _setError("You need at least 10 steps to convert.");
        return false;
      }

      final actualStepsUsed = attackPointsGained * 10;

      // Update Firestore
      final firestoreSuccess = await _firestoreService.updateUserPoints(
        currentUser!.id,
        attackPoints: attackPointsGained,
        stepsUsed: actualStepsUsed,
      );

      // Update Realtime DB
      final realtimeSuccess = await _authService.updateUserPoints(
        currentUser!.id,
        attackPoints: attackPointsGained,
        stepsUsed: actualStepsUsed,
      );

      if (firestoreSuccess && realtimeSuccess) {
        await _stepService.convertStepsToAttackPoints(actualStepsUsed);
        _currentUser = currentUser!.copyWith(
          attackPoints: currentUser!.attackPoints + attackPointsGained,
          totalSteps: currentUser!.totalSteps - actualStepsUsed,
        );
        notifyListeners();
        return true;
      } else {
        _setError("Failed to sync points with the server.");
        return false;
      }
    } catch (e) {
      if (kDebugMode) print('❌ [GameProvider] Error converting steps: $e');
      _setError("An error occurred during conversion.");
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Convert steps to shield points
  Future<bool> convertStepsToShieldPoints(int stepsToConvert) async {
    _setLoading(true);
    _clearError();
    try {
      if (currentUser == null) {
        _setError("User not logged in.");
        return false;
      }

      final availableSteps = _stepService.dailySteps;
      if (stepsToConvert > availableSteps) {
        _setError("Not enough steps to convert.");
        return false;
      }

      // 50 steps = 1 shield point
      final shieldPointsGained = stepsToConvert ~/ 50;
      if (shieldPointsGained == 0) {
        _setError("You need at least 50 steps to convert to a shield point.");
        return false;
      }
      final actualStepsUsed = shieldPointsGained * 50;

      // Update Firestore & RTDB
      final firestoreSuccess = await _firestoreService.updateUserPoints(
        currentUser!.id,
        shieldPoints: shieldPointsGained,
        stepsUsed: actualStepsUsed,
      );
      final realtimeSuccess = await _authService.updateUserPoints(
        currentUser!.id,
        shieldPoints: shieldPointsGained,
        stepsUsed: actualStepsUsed,
      );

      if (firestoreSuccess && realtimeSuccess) {
        // This method just deducts steps from the state manager
        await _stepService.convertStepsToAttackPoints(actualStepsUsed);

        // Update local user
        _currentUser = currentUser!.copyWith(
          shieldPoints: currentUser!.shieldPoints + shieldPointsGained,
          totalSteps: currentUser!.totalSteps - actualStepsUsed,
        );
        notifyListeners();
        return true;
      } else {
        _setError("Failed to sync points with the server.");
        return false;
      }
    } catch (e) {
      _setError("An error occurred during shield conversion.");
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Debug methods
  Future<void> giveTestingPoints(
      {int attackPoints = 50, int shieldPoints = 50}) async {
    if (kDebugMode) {
      await _gameManager.giveCurrentUserTestingPoints(
        attackPoints: attackPoints,
        shieldPoints: shieldPoints,
      );
    }
  }

  Future<void> resetStepCount() async {
    if (kDebugMode) {
      await _gameManager.resetCurrentUserStepCount();
    }
  }

  // Event handlers
  void _onUserUpdate(GameUser user) {
    _currentUser = user;
    _persistGameSession();
    notifyListeners();
  }

  void _onTerritoryUpdate(List<Territory> territories) {
    _territories = territories;
    if (_gameManager.isUserLoggedIn) {
      _gameManager.getCurrentUserTerritories().then((userTerritories) {
        _userTerritories = userTerritories;
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  void _onGameEvent(Map<String, dynamic> event) {
    if (kDebugMode) {
      print('🎮 Game Event: ${event['type']}');
    }
    switch (event['type']) {
      case 'user_login':
        _currentUser = event['user'] as GameUser?;
        _persistGameSession();
        break;
      case 'user_logout':
        _currentUser = null;
        _userTerritories = [];
        _persistence.clearGameSession();
        break;
      case 'attack_launched':
      case 'territory_defended':
      case 'territory_reinforced':
        break;
    }

    notifyListeners();
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    if (kDebugMode) {
      print('🎮 Game Error: $error');
    }
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // MARK: - Persistence Methods

  /// Load persisted game session data
  void _loadPersistedGameSession() {
    try {
      final gameData = _persistence.loadGameSession();
      final wasGameActive = gameData['isGameActive'] as bool;
      final currentUser = gameData['currentUser'] as GameUser?;
      if (wasGameActive && currentUser != null) {
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

  /// Restore game session if we have persisted data
  Future<void> _restoreGameSessionIfNeeded() async {
    if (_currentUser != null && _currentUser!.id.isNotEmpty) {
      try {
        final success = await startGameSession(_currentUser!.id);
        if (success) {
          if (kDebugMode) print('✅ Game session restored successfully');
        } else {
          if (kDebugMode) print('⚠️ Failed to restore game session');
          await _persistence.clearGameSession();
        }
      } catch (e) {
        if (kDebugMode) print('❌ Error restoring game session: $e');
        await _persistence.clearGameSession();
      }
    }
  }

  /// Persist current game session data
  Future<void> _persistGameSession() async {
    try {
      await _persistence.saveGameSession(
        isGameActive: _gameManager.isUserLoggedIn,
        currentUserId: _gameManager.currentUserId,
        currentUser: _currentUser,
        lastStepCount: _gameManager.getCurrentStepCount(),
        lastSyncTime: DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) print('❌ Failed to persist game session: $e');
    }
  }

  /// Initialize the user data
  Future<void> initializeUser() async {
    try {
      _isInitialized = false; // Reset initialization state
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        if (kDebugMode) {
          print(
              '⚠️ No Firebase user found during GameProvider initialization');
        }
        return;
      }

      _currentUser = await _firestoreService.fetchOrCreateUser(firebaseUser);
      _isInitialized = true;

      if (kDebugMode) {
        print('✅ GameProvider initialized with user: ${_currentUser?.nickname}');
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error initializing GameProvider: $e');
      }
      _isInitialized = false;
      rethrow;
    }
  }

  /// Refresh the user data
  Future<void> refreshUser() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      _currentUser = await _firestoreService.fetchOrCreateUser(firebaseUser);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _territoriesSubscription?.cancel();
    _userTerritoriesSubscription?.cancel();
    _gameManager.dispose();
    super.dispose();
  }
}
