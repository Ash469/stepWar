import 'dart:io';
import 'package:games_services/games_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

class PlayGamesService {
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> signInWithPlayGames() async {
    try {
      if (!Platform.isAndroid) return null;

      // 1. Sign in to Native Play Games Service
      // The error you are seeing happens HERE.
      // If Part 1 (SHA-1 fix) is done, this line will finally work.
      // 1. Sign in to Native Play Games Service and get the code directly
      // In games_services 4.1.1, signIn() returns the auth code if successful
      final String? serverAuthCode = await GamesServices.signIn();

      if (serverAuthCode == null) {
        print('Failed to get serverAuthCode from Play Games');
        return null;
      }

      print('Got Auth Code. Swapping for Firebase Credential...');

      // 3. Create Firebase Credential
      final AuthCredential credential = PlayGamesAuthProvider.credential(
        serverAuthCode: serverAuthCode,
      );

      // 4. Sign in to Firebase
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        print('✅ Successfully signed in to Firebase via Play Games!');
        // Sync user data to your backend
        await _authService.syncUserWithBackend(
            uid: user.uid, email: user.email);

        if (!(await _authService.isNewUser(user.uid))) {
          await _authService.cacheUserProfile(user.uid);
        }
      }

      return user;
    } catch (e) {
      print('Error signing in with Play Games: $e');
      // If e is "failed_to_authenticate", it means Part 1 is still not fixed.
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
      // await _googleSignIn.signOut();
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
