import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'firestore_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  // Correctly initialize FirebaseDatabase instance to fix LateInitializationError
  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://stepwars-35179-default-rtdb.asia-southeast1.firebasedatabase.app',
    );

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;
  
  // The explicit initialize method is no longer needed for the database instance.
  // It can be kept for other setup tasks if required.
  Future<void> initialize() async {
    // This can be used for other initialization logic if needed in the future.
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('Missing tokens - AccessToken: ${googleAuth.accessToken != null}, IdToken: ${googleAuth.idToken != null}');
        throw Exception('Failed to obtain Google authentication tokens');
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      UserCredential? userCredential;
      try {
        userCredential = await _auth.signInWithCredential(credential);
        print('Firebase sign-in successful: ${userCredential.user?.email}');
        print('Firebase user UID: ${userCredential.user?.uid}');
        print('Firebase user displayName: ${userCredential.user?.displayName}');
      } catch (authError) {
        if (authError.toString().contains('PigeonUserDetails') || 
            authError.toString().contains('_TypeError') ||
            authError.toString().contains('type \'List<Object?\'')) {
          await Future.delayed(const Duration(milliseconds: 1000));
          final authenticatedUser = _auth.currentUser;
          if (authenticatedUser == null) {
            throw Exception('Google Sign-In failed due to compatibility issues. Please try again.');
          }
        } else {
          throw authError;
        }
      }
      await _storeLoginState(true);
      final currentAuthUser = _auth.currentUser;
      if (userCredential?.user != null) {
        print('Creating/updating user profile for UID: ${userCredential!.user!.uid}');
        await _createOrUpdateUserProfile(userCredential!.user!);
      } else if (currentAuthUser != null) {
        await _createOrUpdateUserProfile(currentAuthUser);
      }
      return userCredential;
    } catch (e) {
      try {
        await _googleSignIn.signOut();
      } catch (signOutError) {
        print('Error signing out from Google after failed sign-in: $signOutError');
      }
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      await _storeLoginState(false);
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  /// Store login state in SharedPreferences
  Future<void> _storeLoginState(bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', isLoggedIn);
    if (isLoggedIn && currentUser != null) {
      await prefs.setString('userEmail', currentUser!.email ?? '');
      await prefs.setString('userId', currentUser!.uid);
      await prefs.setString('firestoreUserId', currentUser!.uid);
    } else {
      await prefs.remove('userEmail');
      await prefs.remove('userId');
      await prefs.remove('firestoreUserId');
    }
  }

  /// Check stored login state
  Future<bool> getStoredLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  /// Get stored user email
  Future<String?> getStoredUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userEmail');
  }

  /// Get stored Firestore user ID
  Future<String?> getStoredFirestoreUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('firestoreUserId');
  }

  /// Create or update user profile in both Realtime Database and Firestore
  Future<void> _createOrUpdateUserProfile(User user) async {
    try {
      final now = DateTime.now();
      final nickname = user.displayName?.isNotEmpty == true 
          ? user.displayName! 
          : user.email?.split('@').first ?? 'Player';

      final gameUser = GameUser(
        id: user.uid,
        nickname: nickname,
        email: user.email,
        photoURL: user.photoURL,
        totalSteps: 0,
        attackPoints: 0,
        shieldPoints: 0,
        attacksUsedToday: 0,
        lastAttackReset: now,
        createdAt: now,
        updatedAt: now,
        territoriesOwned: 0,
        totalAttacksLaunched: 0,
        totalDefensesWon: 0,
        totalTerritoriesCaptured: 0,
        notificationsEnabled: true,
      );
      final firestoreService = FirestoreService();
      await firestoreService.initialize();
      
      final existingUser = await firestoreService.getFirestoreUser(user.uid);
      if (existingUser == null) {
        await firestoreService.createFirestoreUser(user);
        print('✅ Created new user in Firestore: ${user.uid}');
      } else {
        await firestoreService.updateFirestoreUser(gameUser);
        print('✅ Updated existing user in Firestore: ${user.uid}');
      }
      final userRef = _database.ref().child('users').child(user.uid);
      final userSnapshot = await userRef.get();
      if (!userSnapshot.exists) {
        await userRef.set(gameUser.toRealtimeDbMap());
        print('✅ Created user in Realtime Database: ${user.uid}');
      } else {
        final updates = {
          'email': user.email,
          'photo_url': user.photoURL,
          'nickname': nickname,
          'updated_at': ServerValue.timestamp,
        };
        await userRef.update(updates);
        print('✅ Updated user in Realtime Database: ${user.uid}');
      }
    } catch (e) {
      print('Error creating/updating user profile: $e');
      rethrow;
    }
  }

  /// Get user profile from Realtime Database
  Future<GameUser?> getUserProfile(String uid) async {
    try {
      final userRef = _database.ref().child('users').child(uid);
      final userSnapshot = await userRef.get();
      
      if (userSnapshot.exists && userSnapshot.value != null) {
        final rawData = userSnapshot.value;
        Map<String, dynamic> userData;
        
        if (rawData is Map) {
          userData = Map<String, dynamic>.from(rawData);
        } else {
          print('Unexpected data type from Firebase: ${rawData.runtimeType}');
          return null;
        }
        
        return GameUser.fromRealtimeDbMap(userData);
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      print('Error details: ${e.toString()}');
      return null;
    }
  }

  /// Update user profile in Realtime Database
  Future<void> updateUserProfile(GameUser user) async {
    try {
      final userRef = _database.ref().child('users').child(user.id);
      await userRef.update(user.toRealtimeDbMap());
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  /// Update user steps in both Realtime Database and Firestore
  Future<void> updateUserSteps(String userId, int steps) async {
    try {
      // Update Realtime Database
      final userRef = _database.ref().child('users').child(userId);
      await userRef.update({
        'total_steps': steps,
        'updated_at': ServerValue.timestamp,
      });

      // Update Firestore
      final firestoreService = FirestoreService();
      await firestoreService.updateUserSteps(userId, steps);
    } catch (e) {
      print('Error updating user steps: $e');
      rethrow;
    }
  }

  /// Get real-time stream of user data
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
        print('Error parsing user data from stream: $e');
        return null;
      }
    });
  }

  /// Update user's points in Realtime Database
  Future<bool> updateUserPoints(String userId, {
    int? attackPoints,
    int? shieldPoints,
    int? stepsUsed,
  }) async {
    try {
      final userRef = _database.ref().child('users').child(userId);
      final updates = <String, dynamic>{
        'updated_at': ServerValue.timestamp,
      };

      if (attackPoints != null) {
        updates['attack_points'] = ServerValue.increment(attackPoints);
      }
      
      if (shieldPoints != null) {
        updates['shield_points'] = ServerValue.increment(shieldPoints);
      }

      if (stepsUsed != null) {
        updates['total_steps'] = ServerValue.increment(-stepsUsed);
      }

      await userRef.update(updates);

      return true;
    } catch (e) {
      print('Error updating user points: $e');
      return false;
    }
  }
}

//this file is done with only realtime database part
