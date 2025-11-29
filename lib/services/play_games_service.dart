import 'dart:io';
import 'package:games_services/games_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth_service.dart';

class PlayGamesService {
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Google Sign-In configured for Play Games
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Explicitly use the Client ID provided
    clientId:
        '955460127665-hp09qv2hvb63e3b2g3fkdhinf6lcaod4.apps.googleusercontent.com',
    scopes: [
      'email',
      'https://www.googleapis.com/auth/games',
    ],
  );

  /// Sign in with Google Play Games
  /// This provides a gaming-focused authentication experience
  Future<User?> signInWithPlayGames() async {
    try {
      // Only available on Android
      if (!Platform.isAndroid) {
        print('Play Games Services is only available on Android');
        // Fall back to regular Google Sign-In on iOS
        return await _authService.signInWithGoogle();
      }

      // Sign in to Play Games Services
      final signInResult = await GamesServices.signIn();

      if (signInResult == null || signInResult.isEmpty) {
        print('Play Games sign-in was cancelled or failed');
        return null;
      }

      print('Successfully signed in to Play Games Services');

      // Get the player info
      final playerInfo = await getPlayerInfo();
      if (playerInfo != null) {
        print('Player ID: ${playerInfo['playerId']}');
        print('Player Name: ${playerInfo['displayName']}');
      }

      // Now authenticate with Firebase using Google Sign-In
      // This links the Play Games account with Firebase
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('Google sign-in was cancelled');
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
      final user = userCredential.user;

      if (user != null) {
        // Sync with backend
        await _authService.syncUserWithBackend(
            uid: user.uid, email: user.email);

        // Cache user profile if not a new user
        if (!(await _authService.isNewUser(user.uid))) {
          await _authService.cacheUserProfile(user.uid);
        }
      }

      return user;
    } catch (e) {
      print('Error signing in with Play Games: $e');
      rethrow;
    }
  }

  /// Get current player information from Play Games
  Future<Map<String, dynamic>?> getPlayerInfo() async {
    try {
      if (!Platform.isAndroid) {
        return null;
      }

      final playerId = await GamesServices.getPlayerID();
      final playerName = await GamesServices.getPlayerName();
      final playerScore = await GamesServices.getPlayerScore();

      return {
        'playerId': playerId,
        'displayName': playerName,
        'score': playerScore,
      };
    } catch (e) {
      print('Error getting player info: $e');
      return null;
    }
  }

  /// Check if user is signed in to Play Games
  Future<bool> isSignedIn() async {
    try {
      if (!Platform.isAndroid) {
        return false;
      }

      final result = await GamesServices.isSignedIn;
      return result;
    } catch (e) {
      print('Error checking sign-in status: $e');
      return false;
    }
  }

  /// Sign out from Play Games Services
  Future<void> signOut() async {
    try {
      // if (Platform.isAndroid) {
      //   await GamesServices.signOut();
      // }
      await _googleSignIn.signOut();
      await _auth.signOut();
      await _authService.signOut();
    } catch (e) {
      print('Error signing out from Play Games: $e');
      rethrow;
    }
  }

  /// Show achievements (optional - for future use)
  Future<void> showAchievements() async {
    try {
      if (!Platform.isAndroid) {
        return;
      }
      await GamesServices.showAchievements();
    } catch (e) {
      print('Error showing achievements: $e');
    }
  }

  /// Show leaderboards (optional - for future use)
  Future<void> showLeaderboards() async {
    try {
      if (!Platform.isAndroid) {
        return;
      }
      await GamesServices.showLeaderboards();
    } catch (e) {
      print('Error showing leaderboards: $e');
    }
  }

  /// Submit score to leaderboard (optional - for future use)
  Future<void> submitScore({
    required String leaderboardId,
    required int score,
  }) async {
    try {
      if (!Platform.isAndroid) {
        return;
      }
      await GamesServices.submitScore(
        score: Score(
          androidLeaderboardID: leaderboardId,
          value: score,
        ),
      );
    } catch (e) {
      print('Error submitting score: $e');
    }
  }

  /// Unlock achievement (optional - for future use)
  Future<void> unlockAchievement({required String achievementId}) async {
    try {
      if (!Platform.isAndroid) {
        return;
      }
      await GamesServices.unlock(
        achievement: Achievement(androidID: achievementId),
      );
    } catch (e) {
      print('Error unlocking achievement: $e');
    }
  }
}
