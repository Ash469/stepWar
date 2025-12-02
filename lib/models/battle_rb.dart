// lib/models/battle_rb.dart

enum GameStatus { waiting, ongoing, completed, unknown }

enum GameResult { win, KO, draw }

class Game {
  final String gameId;
  final String? player1Id;
  final String? player2Id;
  final int step1Count;
  final int step2Count;
  final double multiplier1;
  final double multiplier2;
  final int player1Score;
  final int player2Score;
  final GameStatus gameStatus;
  final GameResult? result;
  final String? winner;
  final int? startTime;
  final bool player1MultiplierUsed;
  final bool player2MultiplierUsed;
  final Map<String, dynamic>? potentialReward;
  final int winnerCoins;
  final int loserCoins;
  final Map<String, dynamic>? wonItem;

  Game({
    required this.gameId,
    this.player1Id,
    this.player2Id,
    this.step1Count = 0,
    this.step2Count = 0,
    this.multiplier1 = 1.0,
    this.multiplier2 = 1.0,
    this.player1Score = 0,
    this.player2Score = 0,
    this.gameStatus = GameStatus.unknown,
    this.result,
    this.winner,
    this.startTime,
    this.player1MultiplierUsed = false,
    this.player2MultiplierUsed = false,
    this.potentialReward,
    this.winnerCoins = 0,
    this.loserCoins = 0,
    this.wonItem,
  });

  factory Game.fromMap(Map<String, dynamic> data, String id) {
    // Helper to parse rewards safely
    final rewardsData = data['rewards'] != null
        ? Map<String, dynamic>.from(data['rewards'] as Map)
        : <String, dynamic>{};

    return Game(
      gameId: id,
      player1Id: data['player1Id'],
      player2Id: data['player2Id'],
      step1Count: (data['step1Count'] as num? ?? 0).toInt(),
      step2Count: (data['step2Count'] as num? ?? 0).toInt(),
      multiplier1: (data['multiplier1'] as num? ?? 1.0).toDouble(),
      multiplier2: (data['multiplier2'] as num? ?? 1.0).toDouble(),
      player1Score: (data['player1Score'] as num? ?? 0).toInt(),
      player2Score: (data['player2Score'] as num? ?? 0).toInt(),
      gameStatus: _parseGameStatus(data['gameStatus']),
      result: data['result'] != null ? _parseGameResult(data['result']) : null,
      winner: data['winnerId'] ?? data['winner'],

      startTime: data['startTime'],
      player1MultiplierUsed: data['player1MultiplierUsed'] ?? false,
      player2MultiplierUsed: data['player2MultiplierUsed'] ?? false,
      potentialReward: data['potentialReward'] != null
          ? Map<String, dynamic>.from(data['potentialReward'])
          : null,
      winnerCoins: (rewardsData['winnerCoins'] as num? ?? 0).toInt(),
      loserCoins: (rewardsData['loserCoins'] as num? ?? 0).toInt(),
      wonItem: rewardsData['item'] != null
          ? Map<String, dynamic>.from(rewardsData['item'])
          : null,
    );
  }

  static GameStatus _parseGameStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'waiting':
        return GameStatus.waiting;
      case 'ongoing':
        return GameStatus.ongoing;
      case 'completed':
        return GameStatus.completed;
      default:
        return GameStatus.unknown;
    }
  }

  static GameResult? _parseGameResult(String? result) {
    if (result == null) return null;
    switch (result.toUpperCase()) {
      case 'WIN':
        return GameResult.win;
      case 'KO':
        return GameResult.KO;
      case 'DRAW':
        return GameResult.draw;
      default:
        return null;
    }
  }
}
