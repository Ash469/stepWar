import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'package:http/http.dart' as http;
import 'notification_service.dart';
import '../const/string.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final NotificationService _notificationService = NotificationService();
  User? get currentUser => _auth.currentUser;
  String get _baseUrl => getBackendUrl();

  Future<bool> isNewUser(String userId) async {
    try {

      final user = await getUserProfile(userId);
      if (user == null) {
        return true;
      }
      return user.username == null || user.username!.isEmpty;
    } catch (e) {
      print("Error checking if new user: $e");
      return false; // Fail safe
    }
  }

  Future<void> createUserProfile(UserModel user) async {
    await updateUserProfile(user);
  }

  Future<void> updateUserProfile(UserModel user) async {
    if (user.userId.isEmpty) {
      throw Exception("Attempted to update profile with an empty user ID.");
    }

    try {
      final userJson = user.toJson();
      if (user.dob != null) {
        userJson['dob'] = user.dob!.toIso8601String();
      }
      final response = await http.put(
        Uri.parse('$_baseUrl/api/user/profile/${user.userId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userJson),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to sync profile with server: ${response.body}');
      }
      final updatedUser = UserModel.fromJson(jsonDecode(response.body));
      await saveUserSession(updatedUser);
    } catch (e) {
      print("Error in updateUserProfile: $e");
      rethrow;
    }
  }

  Future<UserModel?> getUserProfile(String userId) async {
    print(
        "[AuthService] getUserProfile called. Re-routing to refreshUserProfile to ensure data consistency.");
    return await refreshUserProfile(userId);
  }

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
        await syncUserWithBackend(uid: user.uid, email: user.email);

        if (!(await isNewUser(user.uid))) {
          await cacheUserProfile(user.uid);
        }
      }

      return user;
    } catch (e) {
      print(e.toString());
      rethrow;
    }
  }

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
        await syncUserWithBackend(uid: user.uid, email: user.email);
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

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  Future<void> saveUserSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    final userJson = user.toJson();
    if (user.dob != null) {
      userJson['dob'] = user.dob!.toIso8601String();
    }

    final userProfileString = jsonEncode(userJson);
    await prefs.setString('userProfile', userProfileString);
  }

  Future<UserModel?> refreshUserProfile(String userId) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/user/profile/$userId');
      final response =
          await http.get(uri, headers: {'Content-Type': 'application/json'});
      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);

        print(
            "[AuthService] Fetched profile from backend. Steps: ${userData['todaysStepCount']}");
        final user = UserModel.fromJson(userData);
        
        if (currentUser?.uid == user.userId) {
           print("[AuthService] Updating local session for CURRENT user.");
           await saveUserSession(user);
        } else {
           print("[AuthService] Fetched OTHER user (Opponent). NOT saving to session.");
        }

        return user;
      } else {
        print("Failed to refresh user profile: ${response.body}");
      }
    } catch (e) {
      print("Error refreshing user profile: $e");
    }
    return null;
  }

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
  Future<Map<String, dynamic>> getLifetimeStats(String userId) async {
    if (userId.isEmpty) {
      throw Exception("User ID is required to fetch lifetime stats.");
    }
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/user/activity/stats/$userId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception('Failed to fetch lifetime stats: ${errorBody['error']}');
      }
    } catch (e) {
      print("Error in getLifetimeStats (Flutter): $e");
      rethrow;
    }
  }
}
