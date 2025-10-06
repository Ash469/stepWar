import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  final String _baseUrl = "https://stepwars-backend.onrender.com";

  Future<bool> isNewUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return !doc.exists;
    } catch (e) {
      print("Error checking if new user: $e");
      return false;
    }
  }

  Future<void> createUserProfile(UserModel user) async {
    await _firestore.collection('users').doc(user.userId).set(user.toJson());
    await saveUserSession(user);
    await syncUserWithBackend(uid: user.userId, email: user.email);
  }

Future<void> updateUserProfile(UserModel user) async {
  if (user.userId.isEmpty) {
    throw Exception("Attempted to update profile with an empty user ID.");
  }

  try {
    // 1. Update Firestore (as before)
    await _firestore.collection('users').doc(user.userId).update(user.toJson());

    // --- 2. FIX: Prepare a JSON-safe map before encoding ---
    final userJson = user.toJson();
    if (user.dob != null) {
      // Convert the DateTime object to a standardized string format
      userJson['dob'] = user.dob!.toIso8601String();
    }
    // --- END FIX ---

    // 3. Send the corrected JSON to your Node.js backend
    final response = await http.put(
      Uri.parse('$_baseUrl/api/user/profile/${user.userId}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(userJson), // Use the corrected, JSON-safe map
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to sync profile with server: ${response.body}');
    }

    // 4. Update the local cache/session (as before)
    await saveUserSession(user);

  } catch (e) {
    print("Error in updateUserProfile: $e");
    rethrow;
  }
}

  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromJson(doc.data()!);
      }
    } catch (e) {
      print("Error getting user profile: $e");
    }
    return null;
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
      if (user != null && !(await isNewUser(user.uid))) {
        await cacheUserProfile(user.uid);
        if (!(await isNewUser(user.uid))) {
          await cacheUserProfile(user.uid);
        }
        await syncUserWithBackend(uid: user.uid, email: user.email);
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
        if (!(await isNewUser(user.uid))) {
          await cacheUserProfile(user.uid);
        }
        await syncUserWithBackend(uid: user.uid, email: user.email);
      }
      return user;
    } catch (e) {
      print("Error verifying OTP and signing in: $e");
      rethrow;
    }
  }

  Future<void> signOut() async {
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
    } else {
      // Search for dob from firestore and if it exists convert it to iso8601 string
      final firestoreUser = await getUserProfile(user.userId);
      if (firestoreUser?.dob != null) {
        userJson['dob'] = firestoreUser!.dob!.toIso8601String();
      }
    }
    final userProfileString = jsonEncode(userJson);
    await prefs.setString('userProfile', userProfileString);
  }

  Future<UserModel?> refreshUserProfile(String userId) async {
    try {
      await SharedPreferences.getInstance();
      final uri = Uri.parse('$_baseUrl/api/user/profile/$userId');
      final response =
          await http.get(uri, headers: {'Content-Type': 'application/json'});
      if (response.statusCode == 200) {
        final user = UserModel.fromJson(jsonDecode(response.body));
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

  Future<void> syncStepsToBackend(String userId, int steps) async {
    // print("making api reuest with $userId and $steps");
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
}
