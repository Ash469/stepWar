class DailyActivity {
  final String id; // Format: "${userId}_${date}" e.g., "user123_2024-01-15"
  final String userId;
  final String userNickname;
  final DateTime date;
  
  // Daily step tracking
  final int stepsToday;
  final int stepGoal; // User's daily step goal
  
  // Daily battle activity
  final int battlesStartedToday;
  final int battlesWonToday;
  final int battlesLostToday;
  final int attackPointsSpentToday;
  final int shieldPointsUsedToday;
  
  // Territory status for the day
  final String? ownedTerritoryIdToday; // Territory owned at end of day
  final String? ownedTerritoryNameToday;
  final bool gainedTerritoryToday; // True if user captured a territory today
  final bool lostTerritoryToday; // True if user lost a territory today
  
  // Daily achievements/milestones
  final bool reachedStepGoalToday;
  final bool firstAttackToday;
  final bool firstDefenseToday;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  const DailyActivity({
    required this.id,
    required this.userId,
    required this.userNickname,
    required this.date,
    this.stepsToday = 0,
    this.stepGoal = 10000, // Default 10k steps
    this.battlesStartedToday = 0,
    this.battlesWonToday = 0,
    this.battlesLostToday = 0,
    this.attackPointsSpentToday = 0,
    this.shieldPointsUsedToday = 0,
    this.ownedTerritoryIdToday,
    this.ownedTerritoryNameToday,
    this.gainedTerritoryToday = false,
    this.lostTerritoryToday = false,
    this.reachedStepGoalToday = false,
    this.firstAttackToday = false,
    this.firstDefenseToday = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // Computed properties
  double get stepGoalProgress => stepsToday / stepGoal;
  bool get hasStepGoal => stepGoal > 0;
  bool get isStepGoalMet => stepsToday >= stepGoal;
  int get totalBattlesToday => battlesWonToday + battlesLostToday;
  double get winRateToday => totalBattlesToday > 0 ? (battlesWonToday / totalBattlesToday) : 0.0;
  bool get hasBattleActivity => battlesStartedToday > 0;
  bool get ownsTerritory => ownedTerritoryIdToday != null;
  
  // Generate today's ID for a user
  static String generateId(String userId, DateTime date) {
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return "${userId}_$dateStr";
  }
  
  // Generate ID for today
  static String generateTodayId(String userId) {
    return generateId(userId, DateTime.now());
  }

  // Factory constructors
  factory DailyActivity.fromFirestoreMap(Map<String, dynamic> map) {
    return DailyActivity(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      userNickname: map['user_nickname'] as String,
      date: (map['date'] as dynamic).toDate(),
      stepsToday: map['steps_today'] as int? ?? 0,
      stepGoal: map['step_goal'] as int? ?? 10000,
      battlesStartedToday: map['battles_started_today'] as int? ?? 0,
      battlesWonToday: map['battles_won_today'] as int? ?? 0,
      battlesLostToday: map['battles_lost_today'] as int? ?? 0,
      attackPointsSpentToday: map['attack_points_spent_today'] as int? ?? 0,
      shieldPointsUsedToday: map['shield_points_used_today'] as int? ?? 0,
      ownedTerritoryIdToday: map['owned_territory_id_today'] as String?,
      ownedTerritoryNameToday: map['owned_territory_name_today'] as String?,
      gainedTerritoryToday: map['gained_territory_today'] as bool? ?? false,
      lostTerritoryToday: map['lost_territory_today'] as bool? ?? false,
      reachedStepGoalToday: map['reached_step_goal_today'] as bool? ?? false,
      firstAttackToday: map['first_attack_today'] as bool? ?? false,
      firstDefenseToday: map['first_defense_today'] as bool? ?? false,
      createdAt: (map['created_at'] as dynamic).toDate(),
      updatedAt: (map['updated_at'] as dynamic).toDate(),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'user_id': userId,
      'user_nickname': userNickname,
      'date': date,
      'steps_today': stepsToday,
      'step_goal': stepGoal,
      'battles_started_today': battlesStartedToday,
      'battles_won_today': battlesWonToday,
      'battles_lost_today': battlesLostToday,
      'attack_points_spent_today': attackPointsSpentToday,
      'shield_points_used_today': shieldPointsUsedToday,
      'owned_territory_id_today': ownedTerritoryIdToday,
      'owned_territory_name_today': ownedTerritoryNameToday,
      'gained_territory_today': gainedTerritoryToday,
      'lost_territory_today': lostTerritoryToday,
      'reached_step_goal_today': reachedStepGoalToday,
      'first_attack_today': firstAttackToday,
      'first_defense_today': firstDefenseToday,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  DailyActivity copyWith({
    String? id,
    String? userId,
    String? userNickname,
    DateTime? date,
    int? stepsToday,
    int? stepGoal,
    int? battlesStartedToday,
    int? battlesWonToday,
    int? battlesLostToday,
    int? attackPointsSpentToday,
    int? shieldPointsUsedToday,
    String? ownedTerritoryIdToday,
    String? ownedTerritoryNameToday,
    bool? gainedTerritoryToday,
    bool? lostTerritoryToday,
    bool? reachedStepGoalToday,
    bool? firstAttackToday,
    bool? firstDefenseToday,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyActivity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userNickname: userNickname ?? this.userNickname,
      date: date ?? this.date,
      stepsToday: stepsToday ?? this.stepsToday,
      stepGoal: stepGoal ?? this.stepGoal,
      battlesStartedToday: battlesStartedToday ?? this.battlesStartedToday,
      battlesWonToday: battlesWonToday ?? this.battlesWonToday,
      battlesLostToday: battlesLostToday ?? this.battlesLostToday,
      attackPointsSpentToday: attackPointsSpentToday ?? this.attackPointsSpentToday,
      shieldPointsUsedToday: shieldPointsUsedToday ?? this.shieldPointsUsedToday,
      ownedTerritoryIdToday: ownedTerritoryIdToday ?? this.ownedTerritoryIdToday,
      ownedTerritoryNameToday: ownedTerritoryNameToday ?? this.ownedTerritoryNameToday,
      gainedTerritoryToday: gainedTerritoryToday ?? this.gainedTerritoryToday,
      lostTerritoryToday: lostTerritoryToday ?? this.lostTerritoryToday,
      reachedStepGoalToday: reachedStepGoalToday ?? this.reachedStepGoalToday,
      firstAttackToday: firstAttackToday ?? this.firstAttackToday,
      firstDefenseToday: firstDefenseToday ?? this.firstDefenseToday,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
