import 'package:firebase_database/firebase_database.dart';
import '../models/battle_RB.dart';
import '../models/user_model.dart';
import 'bot_service.dart';

class GameService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final BotService _botService = BotService();

  Future<String> createOnlineGame(UserModel player1) async {
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
      print("Error creating online game: $e");
      rethrow;
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

  Future<void> updatePlayerSteps(String gameId, int newSteps) async {
    try {
      await _dbRef.child('games').child(gameId).update({
        'step1_count': newSteps,
        'player1_score': newSteps,
      });
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
