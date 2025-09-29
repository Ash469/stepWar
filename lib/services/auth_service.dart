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

  User? get currentUser => _auth.currentUser;

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
  }

  Future<void> updateUserProfile(UserModel user) async {
    await _firestore.collection('users').doc(user.userId).update(user.toJson());
    await saveUserSession(user);
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
      }

      return user;
    } catch (e) {
      print(e.toString());
      rethrow;
    }
  }

  Future<void> sendOtpToEmail(String email) async {
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<User?> verifyOtpAndSignIn(String email, String otp) async {
    if (otp == '1234') {
      try {
        UserCredential userCredential;
        try {
          userCredential = await _auth.signInWithEmailAndPassword(
              email: email, password: 'some_default_password_if_known');
        } on FirebaseAuthException catch (e) {
          if (e.code == 'user-not-found') {
            userCredential = await _auth.createUserWithEmailAndPassword(
                email: email,
                password:
                    'temporaryPassword${DateTime.now().millisecondsSinceEpoch}');
          } else {
            rethrow;
          }
        }

        final user = userCredential.user;
        if (user != null && !(await isNewUser(user.uid))) {
          await cacheUserProfile(user.uid);
        }
        return user;
      } catch (e) {
        throw Exception('OTP verification failed');
      }
    } else {
      throw Exception('Invalid OTP');
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
}
