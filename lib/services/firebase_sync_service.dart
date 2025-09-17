import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user.dart';
import 'step_tracking_service.dart';
import 'step_state_manager.dart';
import 'auth_service.dart';

/// Service to sync step data with Firebase Realtime Database
class FirebaseStepSyncService {
  static final FirebaseStepSyncService _instance = FirebaseStepSyncService._internal();
  factory FirebaseStepSyncService() => _instance;
  FirebaseStepSyncService._internal();

  late FirebaseDatabase _database;
  final AuthService _authService = AuthService();
  final StepTrackingService _stepCounter = StepTrackingService();
  final StepStateManager _stateManager = StepStateManager();
  
  StreamSubscription<int>? _stepSubscription;
  StreamSubscription<User?>? _authSubscription;
  
  Timer? _syncTimer;
  String? _currentUserId;
  int _lastSyncedSteps = 0;
  bool _initialized = false;

  /// Initialize the sync service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize Firebase Database with the correct regional URL
      _database = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://stepwars-35179-default-rtdb.asia-southeast1.firebasedatabase.app',
      );

      // Listen to authentication state changes
      _authSubscription = _authService.authStateChanges.listen(_onAuthStateChanged);

      // Check current auth state
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        await _startSyncForUser(currentUser.uid);
      }

      _initialized = true;
      if (kDebugMode) {
        print('✅ Firebase Step Sync Service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize Firebase Step Sync Service: $e');
      }
    }
  }

  /// Handle authentication state changes
  void _onAuthStateChanged(User? user) {
    if (user == null) {
      _stopSync();
    } else {
      _startSyncForUser(user.uid);
    }
  }

  /// Start syncing step data for a specific user
  Future<void> _startSyncForUser(String userId) async {
    if (_currentUserId == userId) return; // Already syncing for this user

    _stopSync(); // Stop any existing sync
    _currentUserId = userId;

    try {
      // IMPORTANT: Initialize steps based on Firebase data for proper login behavior
      if (kDebugMode) {
        print('🔄 Initializing step data from Firebase for user: $userId');
      }
      await _initializeStepsFromFirebase(userId);
      
      // Get current step count after Firebase initialization
      final currentSteps = _stepCounter.dailySteps;
      _lastSyncedSteps = currentSteps;

      // Listen to step updates from the state manager instead of individual service
      _stepSubscription = _stateManager.dailyStepsStream.listen(_onStepsChanged);

      // Set up periodic sync (every 30 seconds as backup)
      _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _performPeriodicSync();
      });

      if (kDebugMode) {
        print('🔄 Started step sync for user: $userId with $_lastSyncedSteps steps');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to start sync for user $userId: $e');
      }
    }
  }

  /// Stop syncing step data
  void _stopSync() {
    _stepSubscription?.cancel();
    _stepSubscription = null;
    
    _syncTimer?.cancel();
    _syncTimer = null;
    
    _currentUserId = null;
    _lastSyncedSteps = 0;

    if (kDebugMode) {
      print('🛑 Step sync stopped');
    }
  }

  /// Handle step count changes
  void _onStepsChanged(int steps) {
    if (_currentUserId == null) return;

    // Only sync if steps have actually changed
    if (steps != _lastSyncedSteps) {
      _syncStepsToFirebase(steps);
      _lastSyncedSteps = steps;
    }
  }

  /// Perform periodic sync as backup
  void _performPeriodicSync() {
    if (_currentUserId == null) return;

    final currentSteps = _stepCounter.dailySteps;
    if (currentSteps != _lastSyncedSteps) {
      _syncStepsToFirebase(currentSteps);
      _lastSyncedSteps = currentSteps;
    }
  }

  /// Sync steps to Firebase Realtime Database
  Future<void> _syncStepsToFirebase(int dailySteps) async {
    if (_currentUserId == null) return;

    try {
      final userRef = _database.ref().child('users').child(_currentUserId!);
      
      // Get existing total steps from Firebase to calculate new total
      final existingTotalSnapshot = await userRef.child('total_steps').get();
      final existingTodaySnapshot = await userRef.child('today_steps').get();
      
      int existingTotal = 0;
      int existingToday = 0;
      
      if (existingTotalSnapshot.exists && existingTotalSnapshot.value != null) {
        final value = existingTotalSnapshot.value;
        if (value is int) existingTotal = value;
        else if (value is double) existingTotal = value.round();
        else if (value is String) existingTotal = int.tryParse(value) ?? 0;
      }
      
      if (existingTodaySnapshot.exists && existingTodaySnapshot.value != null) {
        final value = existingTodaySnapshot.value;
        if (value is int) existingToday = value;
        else if (value is double) existingToday = value.round();
        else if (value is String) existingToday = int.tryParse(value) ?? 0;
      }
      
      // Calculate new total steps
      // If this is the first sync of the day or daily steps reset, adjust total accordingly
      int newTotal = existingTotal;
      if (dailySteps >= existingToday) {
        // Normal case: today's steps increased
        newTotal = existingTotal + (dailySteps - existingToday);
      } else {
        // Day reset case: today's steps is less than yesterday
        // Keep existing total, just update today's steps
        newTotal = existingTotal;
      }
      
      await userRef.update({
        'today_steps': dailySteps,
        'total_steps': newTotal,
        'updated_at': ServerValue.timestamp,
      });

      if (kDebugMode) {
        print('📊 Synced $dailySteps today steps and $newTotal total steps to Firebase for user: $_currentUserId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to sync steps to Firebase: $e');
      }
    }
  }

  /// Get user steps from Firebase (for syncing from other devices)
  Future<Map<String, int>?> getStepsFromFirebase(String userId) async {
    try {
      final userRef = _database.ref().child('users').child(userId);
      final snapshot = await userRef.get();
      
      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        
        int todaySteps = 0;
        int totalSteps = 0;
        
        if (data['today_steps'] != null) {
          final value = data['today_steps'];
          if (value is int) todaySteps = value;
          else if (value is double) todaySteps = value.round();
          else if (value is String) todaySteps = int.tryParse(value) ?? 0;
        }
        
        if (data['total_steps'] != null) {
          final value = data['total_steps'];
          if (value is int) totalSteps = value;
          else if (value is double) totalSteps = value.round();
          else if (value is String) totalSteps = int.tryParse(value) ?? 0;
        }
        
        return {
          'today_steps': todaySteps,
          'total_steps': totalSteps,
        };
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to get steps from Firebase: $e');
      }
      return null;
    }
  }

  /// Initialize steps from Firebase on login - this ensures proper behavior for new vs existing users
  Future<void> _initializeStepsFromFirebase(String userId) async {
    try {
      final firebaseData = await getStepsFromFirebase(userId);
      
      if (firebaseData == null) {
        // New user - no Firebase data exists, start with 0 steps
        _stateManager.initializeSteps(
          dailySteps: 0,
          totalSteps: 0,
          sessionSteps: 0,
          source: 'firebase_new_user',
        );
        
        if (kDebugMode) {
          print('🆕 New user - initialized with 0 steps from Firebase');
        }
      } else {
        // Existing user - load their Firebase step data
        final firebaseTodaySteps = firebaseData['today_steps'] ?? 0;
        final firebaseTotalSteps = firebaseData['total_steps'] ?? 0;
        
        _stateManager.initializeSteps(
          dailySteps: firebaseTodaySteps,
          totalSteps: firebaseTotalSteps,
          sessionSteps: 0,
          source: 'firebase_existing_user',
        );
        
        if (kDebugMode) {
          print('👤 Existing user - loaded Firebase steps: Today: $firebaseTodaySteps, Total: $firebaseTotalSteps');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize steps from Firebase: $e');
      }
      // Fallback to zero initialization
      _stateManager.initializeSteps(
        dailySteps: 0,
        totalSteps: 0,
        sessionSteps: 0,
        source: 'firebase_init_fallback',
      );
    }
  }

  /// Sync steps from Firebase to local (useful when app starts or user switches devices)
  Future<void> syncStepsFromFirebase() async {
    if (_currentUserId == null) return;

    try {
      final firebaseData = await getStepsFromFirebase(_currentUserId!);
      if (firebaseData == null) return;
      
      final firebaseTodaySteps = firebaseData['today_steps'] ?? 0;
      final firebaseTotalSteps = firebaseData['total_steps'] ?? 0;
      final localTodaySteps = _stepCounter.dailySteps;
      
      // If Firebase has more today steps, update local
      if (firebaseTodaySteps > localTodaySteps) {
        final difference = firebaseTodaySteps - localTodaySteps;
        _stepCounter.addSteps(difference, source: 'firebase_sync');
        _lastSyncedSteps = firebaseTodaySteps;
        
        if (kDebugMode) {
          print('📥 Synced $difference today steps from Firebase (Firebase today: $firebaseTodaySteps, Local today: $localTodaySteps)');
          print('📊 Firebase total steps: $firebaseTotalSteps');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to sync steps from Firebase: $e');
      }
    }
  }

  /// Stream of user data changes from Firebase
  Stream<GameUser?> getUserDataStream(String userId) {
    final userRef = _database.ref().child('users').child(userId);
    
    return userRef.onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return null;
      }

      try {
        final data = event.snapshot.value;
        if (data is Map) {
          final userData = Map<String, dynamic>.from(data);
          return GameUser.fromRealtimeDbMap(userData);
        }
        return null;
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error parsing user data from Firebase stream: $e');
        }
        return null;
      }
    });
  }

  /// Update user profile data in Firebase
  Future<void> updateUserProfile(GameUser user) async {
    try {
      final userRef = _database.ref().child('users').child(user.id);
      await userRef.update(user.toRealtimeDbMap());
      
      if (kDebugMode) {
        print('✅ Updated user profile in Firebase: ${user.nickname}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to update user profile in Firebase: $e');
      }
      rethrow;
    }
  }

  /// Force sync current steps to Firebase
  Future<void> forceSyncSteps() async {
    if (_currentUserId == null) return;
    
    final currentSteps = _stepCounter.dailySteps;
    await _syncStepsToFirebase(currentSteps);
    _lastSyncedSteps = currentSteps;
  }

  /// Clear all user-related data (for sign out)
  Future<void> clearUserData() async {
    _stopSync();
    _lastSyncedSteps = 0;
    
    if (kDebugMode) {
      print('🗑️ Firebase sync service user data cleared');
    }
  }

  /// Get sync status
  bool get isSyncing => _currentUserId != null && _stepSubscription != null;
  String? get currentUserId => _currentUserId;
  int get lastSyncedSteps => _lastSyncedSteps;

  /// Dispose of the service
  void dispose() {
    _stopSync();
    _authSubscription?.cancel();
    _authSubscription = null;
    _initialized = false;
    
    if (kDebugMode) {
      print('🗑️ Firebase Step Sync Service disposed');
    }
  }
}
