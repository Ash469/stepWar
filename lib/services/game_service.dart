import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import '../models/battle_RB.dart';
import '../models/user_model.dart';

class GameService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  final String _baseUrl = "http://stepwars.ap-south-1.elasticbeanstalk.com/api";

  Future<String> createPvpBattle(String player1Id, String player2Id) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/battle/pvp/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'player1Id': player1Id,
          'player2Id': player2Id,
        }),
      );
      if (response.statusCode == 201) {
        final responseBody = jsonDecode(response.body);
        final gameId = responseBody['gameId'];
        if (gameId != null) {
          return gameId;
        } else {
          throw Exception('Server did not return a gameId for PvP battle.');
        }
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(
            'Failed to create PvP battle: ${errorBody['error'] ?? 'Unknown server error'}');
      }
    } catch (e) {
      print("Error in createPvpBattle (Flutter): $e");
      rethrow;
    }
  }

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
          throw Exception(
              'Failed to create bot game: Server did not return a gameId.');
        }
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(
            'Failed to create bot game: ${errorBody['error'] ?? 'Unknown server error'}');
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
      throw Exception(
          'Failed to create friend game: ${errorBody['error'] ?? 'Unknown server error'}');
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

  Future<Map<String, dynamic>> endBattle(String gameId,
      {int? player1FinalScore, int? player2FinalScore}) async {
    try {
      final body = <String, dynamic>{
        'gameId': gameId,
      };
      if (player1FinalScore != null) {
        body['player1FinalScore'] = player1FinalScore;
      }
      if (player2FinalScore != null) {
        body['player2FinalScore'] = player2FinalScore;
      }
      final response = await http.post(
        Uri.parse('$_baseUrl/battle/end'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(
            'Failed to end battle: ${errorBody['error'] ?? 'Unknown server error'}');
      }
    } catch (e) {
      print("Error in endBattle (Flutter): $e");
      rethrow;
    }
  }

  Future<void> cancelFriendGame(String gameId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/battle/friend/cancel'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'gameId': gameId}),
      );
      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        throw Exception(
            'Failed to cancel game: ${errorBody['error'] ?? 'Unknown server error'}');
      }
    } catch (e) {
      print("Error in cancelFriendGame (Flutter): $e");
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
          print(
              "--- GameService FATAL ERROR: Failed to parse game data. Error: $e ---");
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
