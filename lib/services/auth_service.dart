import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // --- Profile & User Data ---

  /// Checks if a user profile exists in Firestore.
  Future<bool> isNewUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return !doc.exists;
    } catch (e) {
      print("Error checking if new user: $e");
      return false;
    }
  }

  /// Creates a user profile in Firestore and saves login state locally.
  Future<void> createUserProfile(UserModel user) async {
    await _firestore.collection('users').doc(user.userId).set(user.toJson());
    // After creating profile, save login state and profile to SharedPreferences
    await saveUserSession(user);
  }

  /// [NEW] Updates a user profile in Firestore and saves the updated session locally.
  Future<void> updateUserProfile(UserModel user) async {
    await _firestore.collection('users').doc(user.userId).update(user.toJson());
    // After updating Firestore, save the updated profile to SharedPreferences
    await saveUserSession(user);
  }


  // --- Authentication Methods ---

  /// Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      // If the user profile already exists, cache it to log them in automatically next time.
      final user = userCredential.user;
      if (user != null && !(await isNewUser(user.uid))) {
          await cacheUserProfile(user.uid);
      }

      return user;
    } catch (e) {
      print(e.toString());
      rethrow;
    }
  }

  /// Send OTP to Email
  Future<void> sendOtpToEmail(String email) async {
    print("Sending OTP to $email (mock implementation)");
    await Future.delayed(const Duration(seconds: 1));
  }

  /// Verify OTP and Sign In
  Future<User?> verifyOtpAndSignIn(String email, String otp) async {
    if (otp == '1234') {
        try {
            UserCredential userCredential;
            try {
                userCredential = await _auth.signInWithEmailAndPassword(
                    email: email,
                    password: 'some_default_password_if_known'
                );
            } on FirebaseAuthException catch (e) {
                if (e.code == 'user-not-found') {
                    userCredential = await _auth.createUserWithEmailAndPassword(
                        email: email,
                        password: 'temporaryPassword${DateTime.now().millisecondsSinceEpoch}'
                    );
                } else {
                    rethrow;
                }
            }

            // If the user profile already exists, cache it.
            final user = userCredential.user;
            if (user != null && !(await isNewUser(user.uid))) {
                await cacheUserProfile(user.uid);
            }
            return user;
        } catch (e) {
            print("Failed to sign in with mock OTP: $e");
            throw Exception('OTP verification failed');
        }
    } else {
        throw Exception('Invalid OTP');
    }
  }

  /// Sign out and clear local session
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Checks if a user session exists locally.
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

    // Console log each field for verification
    print("--- User Session Saved/Updated ---");
    print("User ID: ${user.userId}");
    print("Email: ${user.email}");
    print("Username: ${user.username}");
    print("Profile Image URL: ${user.profileImageUrl}");
    print("Date of Birth: ${user.dob}");
    print("Gender: ${user.gender}");
    print("Weight: ${user.weight} kg");
    print("Height: ${user.height} cm");
    print("Contact No: ${user.contactNo}");
    print("Step Goal: ${user.stepGoal}");
    print("Today's Steps: ${user.todaysStepCount}");
    print("--------------------------");
    print("Full Profile JSON: $userProfileString");
  }

  /// Fetches profile from Firestore and saves it to SharedPreferences.
  Future<void> cacheUserProfile(String userId) async {
      try {
          final doc = await _firestore.collection('users').doc(userId).get();
          if (doc.exists) {
              final user = UserModel.fromJson(doc.data()!);
              await saveUserSession(user);
          }
      } catch(e) {
          print("Error caching user profile: $e");
      }
  }
}
