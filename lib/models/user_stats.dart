class UserStats {
  final int dailySteps;
  final int totalSteps;
  final int attackPoints;
  final int shieldPoints;
  final int territoriesOwned;
  final int battlesWon;
  final int battlesLost;
  final int attacksRemaining;

  const UserStats({
    required this.dailySteps,
    required this.totalSteps,
    required this.attackPoints,
    required this.shieldPoints,
    required this.territoriesOwned,
    required this.battlesWon,
    required this.battlesLost,
    required this.attacksRemaining,
  });

  UserStats copyWith({
    int? dailySteps,
    int? totalSteps,
    int? attackPoints,
    int? shieldPoints,
    int? territoriesOwned,
    int? battlesWon,
    int? battlesLost,
    int? attacksRemaining,
  }) {
    return UserStats(
      dailySteps: dailySteps ?? this.dailySteps,
      totalSteps: totalSteps ?? this.totalSteps,
      attackPoints: attackPoints ?? this.attackPoints,
      shieldPoints: shieldPoints ?? this.shieldPoints,
      territoriesOwned: territoriesOwned ?? this.territoriesOwned,
      battlesWon: battlesWon ?? this.battlesWon,
      battlesLost: battlesLost ?? this.battlesLost,
      attacksRemaining: attacksRemaining ?? this.attacksRemaining,
    );
  }

  // Step economy calculations (from requirements)
  int get attackPointsFromSteps => dailySteps ~/ 100; // 100 steps = 1 attack point
  int get shieldPointsFromSteps => dailySteps ~/ 100; // 100 steps = 1 shield point
  int get shieldHitsFromAttackPoints => attackPoints ~/ 10; // 10 attack points = 1 shield hit
}

