import 'dart:io';
import 'package:games_services/games_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

class PlayGamesService {
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Future<User?> attemptSilentSignIn() async {
    try {
      if (!Platform.isAndroid) {
        print('[Play Games] Not on Android, skipping silent sign-in');
        return null;
      }
      final isSignedIn = await GamesServices.isSignedIn;
      if (!isSignedIn) {
        print(
            '[Play Games] User not signed in to Play Games, attempting sign-in...');
      }
      final String? serverAuthCode = await GamesServices.signIn();

      if (serverAuthCode == null) {
        print('[Play Games] Silent sign-in failed - no auth code received');
        return null;
      }

      print(
          '[Play Games] ✅ Silent sign-in successful, authenticating with Firebase...');
      final AuthCredential credential = PlayGamesAuthProvider.credential(
        serverAuthCode: serverAuthCode,
      );
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        print(
            '[Play Games] ✅ Firebase authentication successful for ${user.uid}');
        await _authService.syncUserWithBackend(
            uid: user.uid, email: user.email);

        if (!(await _authService.isNewUser(user.uid))) {
          await _authService.cacheUserProfile(user.uid);
        }
      }

      return user;
    } catch (e) {
      print('[Play Games] Silent sign-in error: $e');
      return null;
    }
  }
  Future<User?> signInWithPlayGames() async {
    try {
      if (!Platform.isAndroid) return null;

      print('[Play Games] Starting manual sign-in...');

      final String? serverAuthCode = await GamesServices.signIn();

      if (serverAuthCode == null) {
        print('[Play Games] Failed to get serverAuthCode from Play Games');
        return null;
      }

      print('[Play Games] Got Auth Code. Swapping for Firebase Credential...');
      final AuthCredential credential = PlayGamesAuthProvider.credential(
        serverAuthCode: serverAuthCode,
      );
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        print(
            '[Play Games] ✅ Successfully signed in to Firebase via Play Games!');
        await _authService.syncUserWithBackend(
            uid: user.uid, email: user.email);

        if (!(await _authService.isNewUser(user.uid))) {
          await _authService.cacheUserProfile(user.uid);
        }
      }

      return user;
    } catch (e) {
      print('[Play Games] Error signing in with Play Games: $e');
      rethrow;
    }
  }
  Future<Map<String, dynamic>?> getPlayerInfo() async {
    try {
      if (!Platform.isAndroid) {
        print('[Play Games] Not on Android, cannot get player info');
        return null;
      }

      final playerId = await GamesServices.getPlayerID();
      final playerName = await GamesServices.getPlayerName();
      final playerScore = await GamesServices.getPlayerScore();

      // Get player icon/avatar URL (if available)
      String? avatarUrl;
      try {
        avatarUrl = null;
      } catch (e) {
        print('[Play Games] Could not fetch avatar: $e');
      }

      print(
          '[Play Games] Player info retrieved - ID: $playerId, Name: $playerName');

      return {
        'playerId': playerId,
        'displayName': playerName,
        'score': playerScore,
        'avatarUrl': avatarUrl,
      };
    } catch (e) {
      print('[Play Games] Error getting player info: $e');
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
