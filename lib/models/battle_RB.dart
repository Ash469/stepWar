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
    this.gameStatus = GameStatus.waiting,
    this.result,
    this.winner,
    this.startTime,
  });

  factory Game.fromMap(Map<dynamic, dynamic> map, String gameId) {
    return Game(
      gameId: gameId,
      player1Id: map['player1_id'] as String?,
      player2Id: map['player2_id'] as String?,
      step1Count: map['step1_count'] as int? ?? 0,
      step2Count: map['step2_count'] as int? ?? 0,
      multiplier1: (map['multiplier1'] as num?)?.toDouble() ?? 1.0,
      multiplier2: (map['multiplier2'] as num?)?.toDouble() ?? 1.0,
      player1Score: map['player1_score'] as int? ?? 0,
      player2Score: map['player2_score'] as int? ?? 0,
      gameStatus: _parseGameStatus(map['gameStatus']),
      result: _parseGameResult(map['result']),
      winner: map['winner'] as String?,
      startTime: map['startTime'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'player1_id': player1Id,
      'player2_id': player2Id,
      'step1_count': step1Count,
      'step2_count': step2Count,
      'multiplier1': multiplier1,
      'multiplier2': multiplier2,
      'player1_score': player1Score,
      'player2_score': player2Score,
      'gameStatus': gameStatus.name,
      'result': result?.name,
      'winner': winner,
      'startTime': startTime,
    };
  }

  Game copyWith({
    String? player1Id,
    String? player2Id,
    int? step1Count,
    int? step2Count,
    double? multiplier1,
    double? multiplier2,
    int? player1Score,
    int? player2Score,
    GameStatus? gameStatus,
    GameResult? result,
    String? winner,
    int? startTime,
  }) {
    return Game(
      gameId: gameId,
      player1Id: player1Id ?? this.player1Id,
      player2Id: player2Id ?? this.player2Id,
      step1Count: step1Count ?? this.step1Count,
      step2Count: step2Count ?? this.step2Count,
      multiplier1: multiplier1 ?? this.multiplier1,
      multiplier2: multiplier2 ?? this.multiplier2,
      player1Score: player1Score ?? this.player1Score,
      player2Score: player2Score ?? this.player2Score,
      gameStatus: gameStatus ?? this.gameStatus,
      result: result ?? this.result,
      winner: winner ?? this.winner,
      startTime: startTime ?? this.startTime,
    );
  }
}

enum GameStatus { waiting, ongoing, completed }

enum GameResult { win, KO, draw }

GameStatus _parseGameStatus(dynamic value) {
  if (value is String) {
    return GameStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => GameStatus.waiting,
    );
  }
  return GameStatus.waiting;
}

GameResult? _parseGameResult(dynamic value) {
  if (value is String) {
    try {
      return GameResult.values.firstWhere((e) => e.name == value);
    } catch (e) {
      return null;
    }
  }
  return null;
}

