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
  late FirebaseDatabase _database;
  
  // Stream to listen to authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Check if user is signed in
  bool get isSignedIn => currentUser != null;

  /// Initialize the auth service
  Future<void> initialize() async {
    _database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://stepwars-35179-default-rtdb.asia-southeast1.firebasedatabase.app',
    );
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('Starting Google Sign-In process...');
      await _googleSignIn.signOut();
      print('Cleared previous Google Sign-In session');
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('Google sign-in was cancelled by user');
        return null;
      }

      print('Google user obtained: ${googleUser.email}');
      print('Google display name: ${googleUser.displayName}');
      print('Google photo URL: ${googleUser.photoUrl}');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('Missing tokens - AccessToken: ${googleAuth.accessToken != null}, IdToken: ${googleAuth.idToken != null}');
        throw Exception('Failed to obtain Google authentication tokens');
      }
      print('Google auth tokens obtained successfully');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('Firebase credential created, signing in...');

      UserCredential? userCredential;
      try {
        userCredential = await _auth.signInWithCredential(credential);
        print('Firebase sign-in successful: ${userCredential.user?.email}');
        print('Firebase user UID: ${userCredential.user?.uid}');
        print('Firebase user displayName: ${userCredential.user?.displayName}');
      } catch (authError) {
        print('Firebase authentication error: $authError');
        print('Firebase auth error type: ${authError.runtimeType}');
        
        // If Firebase auth fails, try to handle the specific error
        if (authError.toString().contains('PigeonUserDetails') || 
            authError.toString().contains('_TypeError') ||
            authError.toString().contains('type \'List<Object?\'')) {
          print('Detected PigeonUserDetails/Type casting error - this is a known Firebase/Google Sign-In compatibility issue');
          print('Attempting workaround...');
          
          // Wait a moment and check if user was actually authenticated
          await Future.delayed(const Duration(milliseconds: 1000));
          
          final authenticatedUser = _auth.currentUser;
          if (authenticatedUser != null) {
            print('Success! User was actually signed in despite the error');
            print('Authenticated user: ${authenticatedUser.email}, UID: ${authenticatedUser.uid}');
            print('Continuing with authentication flow...');
          } else {
            print('Authentication actually failed');
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
        print('User profile created/updated successfully');
      } else if (currentAuthUser != null) {
        print('UserCredential is null but user is authenticated, creating profile for: ${currentAuthUser.uid}');
        await _createOrUpdateUserProfile(currentAuthUser);
        print('User profile created/updated successfully');
      }
      
      return userCredential;
    } catch (e) {
      print('Error signing in with Google: $e');
      print('Error type: ${e.runtimeType}');
      print('Full error details: ${e.toString()}');
      try {
        await _googleSignIn.signOut();
        print('Cleaned up Google Sign-In session after error');
      } catch (signOutError) {
        print('Error during cleanup: $signOutError');
      }
      
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      
      // Sign out from Firebase
      await _auth.signOut();
      
      // Clear login state
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
      await prefs.setString('firestoreUserId', currentUser!.uid); // Store Firestore user ID
      print('💾 Stored Firestore user ID in local storage: ${currentUser!.uid}');
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
      
      // Use Google display name or email as fallback
      final nickname = user.displayName?.isNotEmpty == true 
          ? user.displayName! 
          : user.email?.split('@').first ?? 'Player';

      final gameUser = GameUser(
        id: user.uid,
        nickname: nickname,
        email: user.email,
        photoURL: user.photoURL,
        totalSteps: 0, // New users start with 0 game steps
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

      // Create/update in Firestore (primary storage)
      final firestoreService = FirestoreService();
      await firestoreService.initialize();
      
      final existingUser = await firestoreService.getFirestoreUser(user.uid);
      if (existingUser == null) {
        // Create new user in Firestore
        await firestoreService.createFirestoreUser(user);
        print('✅ Created new user in Firestore: ${user.uid}');
      } else {
        // Update existing user in Firestore
        await firestoreService.updateFirestoreUser(gameUser);
        print('✅ Updated existing user in Firestore: ${user.uid}');
      }

      // Also create/update in Realtime Database (for backward compatibility)
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

  /// Update user nickname (kept for potential future use)
  Future<void> updateUserNickname(String nickname) async {
    if (currentUser == null) throw Exception('No user signed in');
    
    final userRef = _database.ref().child('users').child(currentUser!.uid);
    await userRef.update({
      'nickname': nickname,
      'updated_at': ServerValue.timestamp,
    });
  }

  /// Update user steps in Realtime Database
  Future<void> updateUserSteps(String userId, int steps) async {
    try {
      final userRef = _database.ref().child('users').child(userId);
      await userRef.update({
        'total_steps': steps,
        'updated_at': ServerValue.timestamp,
      });
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

  /// Update multiple user fields at once
  Future<void> updateUserFields(String userId, Map<String, dynamic> updates) async {
    try {
      final userRef = _database.ref().child('users').child(userId);
      final updatedData = Map<String, dynamic>.from(updates);
      updatedData['updated_at'] = ServerValue.timestamp;
      
      await userRef.update(updatedData);
    } catch (e) {
      print('Error updating user fields: $e');
      rethrow;
    }
  }
}


//this file is done with only realtime database part 