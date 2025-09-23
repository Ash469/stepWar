import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  late FirebaseFirestore _firestore;
  bool _isInitialized = false;

  /// Initialize the Firestore service
  Future<bool> initialize() async {
    try {
      _firestore = FirebaseFirestore.instance;
      if (kDebugMode) {
        _firestore.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        if (kDebugMode) {
          print('📋 [FS] Offline persistence enabled for mobile');
        }
      }
      _isInitialized = true;
      if (kDebugMode) {
        print('🔥 Firestore service initialized successfully');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize Firestore: $e');
        print('🔍 Error type: ${e.runtimeType}');
      }
      return false;
    }
  }

  /// Get Firestore instance
  FirebaseFirestore get firestore {
    if (!_isInitialized) {
      throw Exception('Firestore service not initialized. Call initialize() first.');
    }
    return _firestore;
  }

  /// Test Firestore connection by reading the config/runtime document
  Future<bool> testConnection() async {
    try {
      if (!_isInitialized) {
        if (kDebugMode) {
          print('⚠️ Firestore service not initialized');
        }
        return false;
      }

      if (kDebugMode) {
        print('🧪 Testing Firestore connection...');
      }
      DocumentSnapshot doc = await _firestore
          .collection('config')
          .doc('runtime')
          .get(const GetOptions(source: Source.server));

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (kDebugMode) {
          print('✅ Firestore connection test successful!');
          print('📄 Config/runtime document data: $data');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('⚠️ Config/runtime document does not exist, but connection is working');
          print('💡 Consider creating the document in Firebase Console');
        }
        return true; // Connection works even if document doesn't exist
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firestore connection test failed: $e');
        print('🔍 Error type: ${e.runtimeType}');
        
        if (e is FirebaseException) {
          print('🔥 Firebase error code: ${e.code}');
          print('🔥 Firebase error message: ${e.message}');
        }
      }
      return false;
    }
  }
  
  /// Read user document by user ID
  Future<DocumentSnapshot?> getUserDocument(String userId) async {
    try {
      return await _firestore.collection('users').doc(userId).get();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error reading user document: $e');
      }
      return null;
    }
  }

  /// Create or update user document
  Future<bool> createOrUpdateUser(String userId, Map<String, dynamic> userData) async {
    try {
      await _firestore.collection('users').doc(userId).set(userData, SetOptions(merge: true));
      if (kDebugMode) {
        print('✅ User document created/updated successfully');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating/updating user document: $e');
      }
      return false;
    }
  }

  /// Get config document
  Future<DocumentSnapshot?> getConfigDocument(String configType) async {
    try {
      return await _firestore.collection('config').doc(configType).get();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error reading config document: $e');
      }
      return null;
    }
  }

  /// Listen to user document changes
  Stream<DocumentSnapshot> listenToUserDocument(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  /// Listen to config document changes
  Stream<DocumentSnapshot> listenToConfigDocument(String configType) {
    return _firestore.collection('config').doc(configType).snapshots();
  }


  
  /// Get users collection reference
  CollectionReference get _users => _firestore.collection('users');
  
  Future<GameUser?> fetchOrCreateUser(User firebaseUser, {int? existingSteps}) async {
    if (!_isInitialized) {
      if (kDebugMode) {
        print('❌ [FS-User] Firestore service not initialized');
      }
      return null;
    }

    try {
      if (kDebugMode) {
        print('🔍 [FS-User] Fetching user data for: ${firebaseUser.uid}');
        print('📧 [FS-User] Email: ${firebaseUser.email}');
        print('🏷️ [FS-User] Display Name: ${firebaseUser.displayName}');
      }

      // First, try to get existing user
      final existingUser = await getFirestoreUser(firebaseUser.uid);
      
      if (existingUser != null) {
        if (kDebugMode) {
          print('✅ [FS-User] Found existing user: ${existingUser.nickname}');
          print('📊 [FS-User] User stats: ${existingUser.totalSteps} steps, ${existingUser.territoriesOwned} territories');
          print('🎯 [FS-User] Battle record: ${existingUser.totalAttacksLaunched} attacks, ${existingUser.totalDefensesWon} defenses won');
        }
        
        // Update last active date
        await _updateUserLastActive(firebaseUser.uid);
        
        return existingUser;
      }

      // User doesn't exist, create new user
      if (kDebugMode) {
        print('🆕 [FS-User] User not found in Firestore. Creating new user document...');
      }
      
      return await createFirestoreUser(firebaseUser, existingSteps: existingSteps);
      
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ [FS-User] Failed to fetch or create user: $e');
        print('🔍 [FS-User] Stack trace: $stackTrace');
        
        if (e is FirebaseException) {
          print('🔥 [FS-User] Firebase error code: ${e.code}');
          print('🔥 [FS-User] Firebase error message: ${e.message}');
        }
      }
      return null;
    }
  }
  
  /// Get user from Firestore by user ID
  Future<GameUser?> getFirestoreUser(String userId) async {
    try {
      if (kDebugMode) {
        print('📖 [FS-User] Reading user document: $userId');
      }
      
      final doc = await _users.doc(userId).get();
      
      if (!doc.exists) {
        if (kDebugMode) {
          print('📭 [FS-User] User document does not exist: $userId');
        }
        return null;
      }
      
      final data = doc.data() as Map<String, dynamic>;
      if (kDebugMode) {
        print('📄 [FS-User] Raw user data: $data');
      }
      
      final user = GameUser.fromFirestoreMap(data);
      
      if (kDebugMode) {
        print('✅ [FS-User] Successfully parsed user: ${user.nickname}');
      }
      
      return user;
      
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ [FS-User] Error reading user document: $e');
        print('🔍 [FS-User] Stack trace: $stackTrace');
      }
      return null;
    }
  }
  
  /// Create a new user document in Firestore
  Future<GameUser?> createFirestoreUser(User firebaseUser, {int? existingSteps}) async {
    try {
      final now = DateTime.now();
      final nickname = firebaseUser.displayName ?? 'Player${firebaseUser.uid.substring(0, 6)}';
      
      if (kDebugMode) {
        print('🔨 [FS-User] Creating new user document...');
        print('👤 [FS-User] Nickname: $nickname');
        print('📧 [FS-User] Email: ${firebaseUser.email}');
        print('🏃‍♂️ [FS-User] Migrating steps: ${existingSteps ?? 0}');
      }
      
      final userData = {
        'id': firebaseUser.uid,
        'nickname': nickname,
        'email': firebaseUser.email,
        'photo_url': firebaseUser.photoURL,
        'signup_date': FieldValue.serverTimestamp(),
        'last_active_date': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'last_attack_reset': now,
        
        // MVP fields as per requirements
        'total_steps': existingSteps ?? 0,
        'total_battles': 0,
        'total_wins': 0,
        
        // Game stats
        'attack_points': 0,
        'shield_points': 0,
        'attacks_used_today': 0,
        'territories_owned': 0,
        'total_attacks_launched': 0,
        'total_defenses_won': 0,
        'total_territories_captured': 0,
        
        // Settings
        'notifications_enabled': true,
        'device_token': null,
        
      };
      
      if (kDebugMode) {
        print('📝 [FS-User] User data to write: $userData');
      }
      
      await _users.doc(firebaseUser.uid).set(userData);
      
      if (kDebugMode) {
        print('✅ [FS-User] Successfully created user document');
      }
      await Future.delayed(const Duration(milliseconds: 500)); 
      return await getFirestoreUser(firebaseUser.uid);
      
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ [FS-User] Failed to create user document: $e');
        print('🔍 [FS-User] Stack trace: $stackTrace');
        
        if (e is FirebaseException) {
          print('🔥 [FS-User] Firebase error code: ${e.code}');
          print('🔥 [FS-User] Firebase error message: ${e.message}');
        }
      }
      return null;
    }
  }
  
  /// Update user's last active timestamp
  Future<bool> _updateUserLastActive(String userId) async {
    try {
      await _users.doc(userId).update({
        'last_active_date': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      if (kDebugMode) {
        print('🔄 [FS-User] Updated last active for user: $userId');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [FS-User] Failed to update last active: $e');
      }
      return false;
    }
  }
  
  /// Update user data in Firestore
  Future<bool> updateFirestoreUser(GameUser user) async {
    try {
      if (kDebugMode) {
        print('📝 [FS-User] Updating user: ${user.nickname}');
      }
      
      final userData = user.toFirestoreMap();
      userData['updated_at'] = FieldValue.serverTimestamp();
      
      await _users.doc(user.id).set(userData, SetOptions(merge: true));
      
      if (kDebugMode) {
        print('✅ [FS-User] Successfully updated user document');
      }
      
      return true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ [FS-User] Failed to update user: $e');
        print('🔍 [FS-User] Stack trace: $stackTrace');
      }
      return false;
    }
  }
  
  /// Display user data in console (for debugging)
  void displayUserData(GameUser user) {
    if (kDebugMode) {
      print('firestore user data saved successfully');
    }
  }
  
  /// Get user stats summary for display
  Map<String, dynamic> getUserStatsSummary(GameUser user) {
    final now = DateTime.now();
    final daysSinceCreation = now.difference(user.createdAt).inDays + 1;
    final avgStepsPerDay = user.totalSteps / daysSinceCreation;
    
    final attackSuccessRate = user.totalAttacksLaunched > 0
        ? (user.totalTerritoriesCaptured / user.totalAttacksLaunched) * 100
        : 0.0;
    
    return {
      'basic_stats': {
        'nickname': user.nickname,
        'total_steps': user.totalSteps,
        'territories_owned': user.territoriesOwned,
        'attack_points': user.attackPoints,
        'shield_points': user.shieldPoints,
        'days_active': daysSinceCreation,
      },
      'battle_stats': {
        'total_attacks': user.totalAttacksLaunched,
        'defenses_won': user.totalDefensesWon,
        'territories_captured': user.totalTerritoriesCaptured,
        'attack_success_rate': attackSuccessRate.toStringAsFixed(1) + '%',
      },
      'activity_stats': {
        'avg_steps_per_day': avgStepsPerDay.round(),
        'attacks_remaining_today': 3 - user.attacksUsedToday,
        'can_attack_today': user.attacksUsedToday < 3,
      },
      'timestamps': {
        'created_at': user.createdAt.toIso8601String(),
        'updated_at': user.updatedAt.toIso8601String(),
        'last_attack_reset': user.lastAttackReset.toIso8601String(),
      },
    };
  }
  
  /// Listen to user document changes in real-time
  Stream<GameUser?> listenToFirestoreUser(String userId) {
    return _users.doc(userId).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      
      try {
        final data = doc.data() as Map<String, dynamic>;
        return GameUser.fromFirestoreMap(data);
      } catch (e) {
        if (kDebugMode) {
          print('❌ [FS-User] Error parsing user from stream: $e');
        }
        return null;
      }
    });
  }
  
  /// Update user steps in Firestore
  Future<bool> updateUserSteps(String userId, int steps) async {
    try {
      if (!_isInitialized) {
        if (kDebugMode) print('❌ [FS] Firestore service not initialized');
        return false;
      }

      final userDoc = _firestore.collection('users').doc(userId);
      
      await userDoc.update({
        'total_steps': steps,
        'updated_at': FieldValue.serverTimestamp(),
        'last_step_sync': DateTime.now().toIso8601String(),
      });

      if (kDebugMode) {
        print('✅ [FS] Steps updated in Firestore: $steps');
      }

      // Also update daily activity if exists
      try {
        final today = DateTime.now();
        final activityId = '${userId}_${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        
        final dailyActivityDoc = _firestore.collection('daily_activities').doc(activityId);
        final activitySnapshot = await dailyActivityDoc.get();

        if (activitySnapshot.exists) {
          await dailyActivityDoc.update({
            'steps_today': steps,
            'updated_at': FieldValue.serverTimestamp(),
          });
          if (kDebugMode) print('✅ [FS] Daily activity steps updated');
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ [FS] Error updating daily activity: $e');
        // Don't fail the whole operation if daily activity update fails
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [FS] Error updating steps in Firestore: $e');
        if (e is FirebaseException) {
          print('🔥 [FS] Firebase error code: ${e.code}');
          print('🔥 [FS] Firebase error message: ${e.message}');
        }
      }
      return false;
    }
  }
  
  /// Update user's attack and shield points
  Future<bool> updateUserPoints(String userId, {
    int? attackPoints,
    int? shieldPoints,
    int? stepsUsed,
  }) async {
    try {
      if (!_isInitialized) {
        if (kDebugMode) print('❌ [FS] Firestore service not initialized');
        return false;
      }

      final userDoc = _firestore.collection('users').doc(userId);
      final updates = <String, dynamic>{
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (attackPoints != null) {
        updates['attack_points'] = FieldValue.increment(attackPoints);
      }
      
      if (shieldPoints != null) {
        updates['shield_points'] = FieldValue.increment(shieldPoints);
      }

      if (stepsUsed != null) {
        updates['total_steps'] = FieldValue.increment(-stepsUsed);
      }

      await userDoc.update(updates);

      if (kDebugMode) {
        print('✅ [FS] Points updated in Firestore:');
        print('   • Attack Points: ${attackPoints ?? 0}');
        print('   • Shield Points: ${shieldPoints ?? 0}');
        print('   • Steps Used: ${stepsUsed ?? 0}');
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('❌ [FS] Error updating points: $e');
      return false;
    }
  }

  /// Dispose resources (if needed)
  void dispose() {
    // Clean up any resources if necessary
    if (kDebugMode) {
      print('🔥 Firestore service disposed');
    }
  }
}
