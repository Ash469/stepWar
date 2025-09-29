import 'package:firebase_database/firebase_database.dart';
import '../models/battle_RB.dart';
import '../models/user_model.dart';
import 'bot_service.dart';

class GameService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final BotService _botService = BotService();

  Future<String> createBotGame(UserModel player1) async {
    try {
      final newGameRef = _dbRef.child('games').push();
      final gameId = newGameRef.key;

      if (gameId == null) {
        throw Exception("Failed to create game: No key generated.");
      }

      final botType = _botService.selectRandomBot();
      final botId = _botService.getBotId(botType);

      final newGame = Game(
        gameId: gameId,
        player1Id: player1.userId,
        player2Id: botId,
        gameStatus: GameStatus.ongoing,
        startTime: DateTime.now().millisecondsSinceEpoch,
      );

      await newGameRef.set(newGame.toMap());
      return gameId;
    } catch (e) {
      print("Error creating bot game: $e");
      rethrow;
    }
  }

  Future<String> createFriendGame(UserModel player1) async {
    try {
      final newGameRef = _dbRef.child('games').push();
      final gameId = newGameRef.key;

      if (gameId == null) {
        throw Exception("Failed to create friend game: No key generated.");
      }

      final newGame = Game(
        gameId: gameId,
        player1Id: player1.userId,
        // player2Id is null until someone joins
        gameStatus: GameStatus.waiting,
        // startTime is null until player 2 joins
      );

      await newGameRef.set(newGame.toMap());
      return gameId;
    } catch (e) {
      print("Error creating friend game: $e");
      rethrow;
    }
  }

  Future<bool> joinFriendGame(String gameId, UserModel player2) async {
    try {
      final gameRef = _dbRef.child('games').child(gameId);
      final snapshot = await gameRef.get();

      if (snapshot.exists) {
        final game = Game.fromMap(
            Map<String, dynamic>.from(snapshot.value as Map), gameId);

        // Check if the game is available to join
        if (game.gameStatus == GameStatus.waiting && game.player2Id == null) {
          await gameRef.update({
            'player2_id': player2.userId,
            'gameStatus': GameStatus.ongoing.name,
            'startTime': DateTime.now().millisecondsSinceEpoch,
          });
          return true;
        }
      }
      return false; // Game not found or already full
    } catch (e) {
      print("Error joining friend game: $e");
      return false;
    }
  }

  Stream<Game?> getGameStream(String gameId) {
    return _dbRef.child('games').child(gameId).onValue.map((event) {
      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        return Game.fromMap(data, gameId);
      }
      return null;
    });
  }

  Future<void> updatePlayerSteps(String gameId, int newSteps, bool isPlayer1) async {
    try {
      if (isPlayer1) {
        await _dbRef.child('games').child(gameId).update({
          'step1_count': newSteps,
          'player1_score': newSteps,
        });
      } else {
        await _dbRef.child('games').child(gameId).update({
          'step2_count': newSteps,
          'player2_score': newSteps,
        });
      }
    } catch (e) {
      print("Error updating player steps: $e");
    }
  }

  Future<void> updateGame(String gameId, Map<String, Object?> data) async {
    try {
      await _dbRef.child('games').child(gameId).update(data);
    } catch (e) {
      print("Error updating game: $e");
    }
  }
}

