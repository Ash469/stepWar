import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';


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
    // Initialize Firebase Database with the correct regional URL
    _database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://stepwars-35179-default-rtdb.asia-southeast1.firebasedatabase.app',
    );
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('Starting Google Sign-In process...');
      
      // Sign out from any previous session to ensure clean state
      await _googleSignIn.signOut();
      print('Cleared previous Google Sign-In session');
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled the sign-in
        print('Google sign-in was cancelled by user');
        return null;
      }

      print('Google user obtained: ${googleUser.email}');
      print('Google display name: ${googleUser.displayName}');
      print('Google photo URL: ${googleUser.photoUrl}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('Missing tokens - AccessToken: ${googleAuth.accessToken != null}, IdToken: ${googleAuth.idToken != null}');
        throw Exception('Failed to obtain Google authentication tokens');
      }

      print('Google auth tokens obtained successfully');

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('Firebase credential created, signing in...');

      // Sign in to Firebase with the Google credential
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
            
            // Bypass the error since the user is authenticated
            // We'll handle the profile creation separately
            print('Continuing with authentication flow...');
          } else {
            print('Authentication actually failed');
            throw Exception('Google Sign-In failed due to compatibility issues. Please try again.');
          }
        } else {
          throw authError;
        }
      }
      
      // Store login state
      await _storeLoginState(true);
      
      // Create or update user profile in Database
      final currentAuthUser = _auth.currentUser;
      if (userCredential?.user != null) {
        print('Creating/updating user profile for UID: ${userCredential!.user!.uid}');
        await _createOrUpdateUserProfile(userCredential!.user!);
        print('User profile created/updated successfully');
      } else if (currentAuthUser != null) {
        // Handle case where userCredential is null but user is authenticated
        print('UserCredential is null but user is authenticated, creating profile for: ${currentAuthUser.uid}');
        await _createOrUpdateUserProfile(currentAuthUser);
        print('User profile created/updated successfully');
      }
      
      return userCredential;
    } catch (e) {
      print('Error signing in with Google: $e');
      print('Error type: ${e.runtimeType}');
      print('Full error details: ${e.toString()}');
      
      // Clean up on error
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
      // Sign out from Google
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
    } else {
      await prefs.remove('userEmail');
      await prefs.remove('userId');
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

  /// Create or update user profile in Realtime Database
  Future<void> _createOrUpdateUserProfile(User user) async {
    try {
      final userRef = _database.ref().child('users').child(user.uid);
      final userSnapshot = await userRef.get();
      
      final now = DateTime.now();
      
      if (!userSnapshot.exists) {
        // Create new user profile using Google display name directly
        // Use Google display name or email as fallback
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
        
        await userRef.set(gameUser.toRealtimeDbMap());
      } else {
        // Update existing user profile with latest Firebase user info
        // Also update nickname if Google display name has changed
        final updates = {
          'email': user.email,
          'photo_url': user.photoURL,
          'updated_at': ServerValue.timestamp,
        };
        
        // Update nickname from Google if it exists
        if (user.displayName?.isNotEmpty == true) {
          updates['nickname'] = user.displayName!;
        }
        
        await userRef.update(updates);
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
        // Handle the case where Firebase returns data in different formats
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
