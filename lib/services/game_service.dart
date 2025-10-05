import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import '../models/battle_RB.dart';
import '../models/user_model.dart';

class GameService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  final String _baseUrl = "https://stepwars-backend.onrender.com/api"; 


  Future<String> createBotGame(UserModel player1, {String? botId}) async {
    try {
      final body = <String, dynamic>{
        'userId': player1.userId,
      };
      if (botId != null) {
        body['botId'] = botId;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/battle/bot'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final responseBody = jsonDecode(response.body);
        final gameId = responseBody['gameId'];
        if (gameId != null) {
          return gameId;
        } else {
           throw Exception('Failed to create bot game: Server did not return a gameId.');
        }
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception('Failed to create bot game: ${errorBody['error'] ?? 'Unknown server error'}');
      }
    } catch (e) {
      print("Error in createBotGame (Flutter): $e");
      rethrow;
    }
  }

  Future<String> createFriendGame(UserModel player1) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/battle/friend/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': player1.userId}),
      );

      if (response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final gameId = body['gameId'];
        if (gameId != null) {
          return gameId;
        }
      }
      final errorBody = jsonDecode(response.body);
      throw Exception('Failed to create friend game: ${errorBody['error'] ?? 'Unknown server error'}');
    } catch (e) {
      print("Error in createFriendGame (Flutter): $e");
      rethrow;
    }
  }

  Future<bool> joinFriendGame(String gameId, UserModel player2) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/battle/friend/join'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'gameId': gameId.trim(), 'userId': player2.userId}),
      );
      
      if (response.statusCode != 200) {
        print("Failed to join game: ${response.body}");
        return false;
      }
      return true;
    } catch (e) {
      print("Error in joinFriendGame (Flutter): $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> endBattle(String gameId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/battle/end'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'gameId': gameId}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception('Failed to end battle: ${errorBody['error'] ?? 'Unknown server error'}');
      }
    } catch (e) {
      print("Error in endBattle (Flutter): $e");
      rethrow;
    }
  }

  Stream<Game?> getGameStream(String gameId) {
    return _dbRef.child('games').child(gameId).onValue.map((event) {
      if (event.snapshot.exists) {
        try {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          return Game.fromMap(data, gameId);
        } catch (e) {
          print("--- GameService FATAL ERROR: Failed to parse game data. Error: $e ---");
          return null;
        }
      }
      return null;
    });
  }

  Future<void> updateGame(String gameId, Map<String, Object?> data) async {
    try {
      await _dbRef.child('games').child(gameId).update(data);
    } catch (e) {
      print("Error updating game in RTDB: $e");
    }
  }

  Future<void> useMultiplier({
    required String gameId,
    required String userId,
    required String multiplierType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/battle/use-multiplier'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'gameId': gameId,
          'userId': userId,
          'multiplierType': multiplierType,
        }),
      );

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to activate multiplier');
      }
    } catch (e) {
      print("Error in useMultiplier (Flutter): $e");
      rethrow;
    }
  }

}
