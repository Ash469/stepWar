import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
// REMOVED: import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'package:http/http.dart' as http;
import 'notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final NotificationService _notificationService = NotificationService();
  // REMOVED: final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? get currentUser => _auth.currentUser;
  final String _baseUrl = "http://stepwars.ap-south-1.elasticbeanstalk.com";

  /// --- MODIFIED ---
  /// Checks if a user is "new" by fetching their profile from our backend
  /// and seeing if they have a username.
  Future<bool> isNewUser(String userId) async {
    try {
      // Get the profile from our backend (the single source of truth)
      final user = await getUserProfile(userId);
      if (user == null) {
        return true; // No profile exists, they are new
      }
      // A "new user" is one who hasn't completed their profile (no username)
      return user.username == null || user.username!.isEmpty;
    } catch (e) {
      print("Error checking if new user: $e");
      return false; // Fail safe
    }
  }

  /// --- MODIFIED ---
  /// Creates the user profile by calling updateUserProfile.
  /// This now only talks to your backend API.
  Future<void> createUserProfile(UserModel user) async {
    // This function is now just an alias for updateUserProfile.
    await updateUserProfile(user);
  }

  /// --- MODIFIED ---
  /// Updates the user profile ONLY via your backend API.
  /// Firestore is no longer touched.
  Future<void> updateUserProfile(UserModel user) async {
    if (user.userId.isEmpty) {
      throw Exception("Attempted to update profile with an empty user ID.");
    }

    try {
      // REMOVED: Firestore update call

      final userJson = user.toJson();
      if (user.dob != null) {
        userJson['dob'] = user.dob!.toIso8601String();
      }

      // THIS is now the single source of truth
      final response = await http.put(
        Uri.parse('$_baseUrl/api/user/profile/${user.userId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userJson),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to sync profile with server: ${response.body}');
      }

      // Save the updated user *from the server response* to the session
      final updatedUser = UserModel.fromJson(jsonDecode(response.body));
      await saveUserSession(updatedUser);
    } catch (e) {
      print("Error in updateUserProfile: $e");
      rethrow;
    }
  }

  /// This is the single source of truth for loading a user.
  /// It is an alias for refreshUserProfile.
  Future<UserModel?> getUserProfile(String userId) async {
    print(
        "[AuthService] getUserProfile called. Re-routing to refreshUserProfile to ensure data consistency.");
    return await refreshUserProfile(userId);
  }

  /// This function is safe. It just calls your backend API
  /// to ensure a user record exists in MongoDB.
  Future<void> syncUserWithBackend({String? uid, String? email}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/sync-user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid, 'email': email}),
      );
      if (response.statusCode == 200) {
        print("User synced successfully with backend.");
      } else {
        print("Failed to sync user with backend: ${response.body}");
      }
    } catch (e) {
      print("Error syncing user with backend: $e");
    }
  }

  /// --- MODIFIED ---
  /// Updated Google Sign-In flow.
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      final user = userCredential.user;
      if (user != null) {
        // 1. Sync user first. This is CRITICAL.
        // This ensures the user exists in MongoDB *before* we check if they are new.
        // Your backend `syncUser` is now just an upsert, so this is safe.
        await syncUserWithBackend(uid: user.uid, email: user.email);

        // 2. Now, check if they are "new" (profile incomplete)
        // This will call getUserProfile -> refreshUserProfile -> MongoDB
        if (!(await isNewUser(user.uid))) {
          // If not new, cache their profile. This will fetch the user
          // from MongoDB with the correct 0 steps (if reset).
          await cacheUserProfile(user.uid);
        }
      }

      return user;
    } catch (e) {
      print(e.toString());
      rethrow;
    }
  }

  // --- ADDED BACK ---
  /// Sends OTP request to the backend.
  Future<void> sendOtpToEmail(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to send OTP: ${response.body}');
      }
    } catch (e) {
      print("Error sending OTP via backend: $e");
      rethrow;
    }
  }
  // --- END ADDED BACK ---

  /// --- MODIFIED ---
  /// Updated OTP Sign-In flow.
  Future<User?> verifyOtpAndSignIn(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp}),
      );

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Invalid OTP');
      }

      final responseBody = jsonDecode(response.body);
      final String? customToken = responseBody['token'];

      if (customToken == null) {
        throw Exception(
            'Authentication token was not received from the server.');
      }
      final userCredential = await _auth.signInWithCustomToken(customToken);

      final user = userCredential.user;
      if (user != null) {
        // 1. Sync user first.
        await syncUserWithBackend(uid: user.uid, email: user.email);

        // 2. Check if new and cache if not.
        if (!(await isNewUser(user.uid))) {
          await cacheUserProfile(user.uid);
        }
      }
      return user;
    } catch (e) {
      print("Error verifying OTP and signing in: $e");
      rethrow;
    }
  }

  /// No changes needed.
  Future<void> signOut() async {
    try {
      final uid = _auth.currentUser?.uid;
      final token = await _notificationService.getFcmToken();
      if (uid != null && token != null) {
        await _notificationService.unregisterTokenFromBackend(uid, token);
      }
    } catch (e) {
      print("Error during token un-registration on logout: $e");
    }
    await _googleSignIn.signOut();
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// No changes needed.
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  /// --- MODIFIED ---
  /// Removed the Firestore fallback for 'dob'.
  Future<void> saveUserSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    final userJson = user.toJson();
    if (user.dob != null) {
      userJson['dob'] = user.dob!.toIso8601String();
    }
    // REMOVED: Firestore fallback logic

    final userProfileString = jsonEncode(userJson);
    await prefs.setString('userProfile', userProfileString);
  }

  /// No changes needed. This is the core function to get data.
  Future<UserModel?> refreshUserProfile(String userId) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/user/profile/$userId');
      final response =
          await http.get(uri, headers: {'Content-Type': 'application/json'});
      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);

        print(
            "[AuthService] Fetched profile from backend.User steps : ${userData['todaysStepCount']}");
        final user = UserModel.fromJson(userData);
        await saveUserSession(user);
        return user;
      } else {
        print("Failed to refresh user profile: ${response.body}");
      }
    } catch (e) {
      print("Error refreshing user profile: $e");
    }
    return null;
  }

  /// No changes needed.
  Future<void> syncStepsToBackend(String userId, int steps) async {
    if (userId.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/user/sync-steps'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': userId, 'todaysStepCount': steps}),
      );

      if (response.statusCode == 200) {
        print("Successfully synced $steps steps to backend.");
      } else {
        print("Failed to sync steps to backend: ${response.body}");
      }
    } catch (e) {
      print("Error syncing steps to backend: $e");
    }
  }

  /// No changes needed.
  Future<void> cacheUserProfile(String userId) async {
    try {
      final user = await getUserProfile(userId);
      if (user != null) {
        await saveUserSession(user);
      }
    } catch (e) {
      print("Error caching user profile: $e");
    }
  }

  /// No changes needed.
  Future<Map<String, List<dynamic>>> getUserRewards(String userId) async {
    if (userId.isEmpty) {
      throw Exception("User ID is required to fetch rewards.");
    }
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/user/rewards/$userId'),
      );

      if (response.statusCode == 200) {
        print("response of reward ${response.body} ");
        return Map<String, List<dynamic>>.from(jsonDecode(response.body));
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception('Failed to fetch rewards: ${errorBody['error']}');
      }
    } catch (e) {
      print("Error in getUserRewards (Flutter): $e");
      rethrow;
    }
  }

  /// No changes needed.
  Future<List<dynamic>> getActivityHistory(String userId) async {
    if (userId.isEmpty) {
      throw Exception("User ID is required to fetch activity history.");
    }
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/user/activity/$userId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception('Failed to fetch activity: ${errorBody['error']}');
      }
    } catch (e) {
      print("Error in getActivityHistory (Flutter): $e");
      rethrow;
    }
  }
}
