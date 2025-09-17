enum BattleResult {
  ongoing,
  attackerWin,
  defenderWin,
  abandoned,
}

class Battle {
  final String id;
  final String attackerId;
  final String attackerNickname;
  final String? defenderId; // null if territory is unowned
  final String? defenderNickname;
  final String territoryId;
  final String territoryName;
  
  // Battle progress tracking
  final int stepsBurnedByAttacker;
  final int stepsBurnedByDefender;
  final int attackPointsSpent; // Converted from attacker steps
  final int shieldPointsAdded; // Converted from defender steps
  final int initialShield; // Shield when battle started
  final int currentShield; // Current shield during battle
  
  // Battle metadata
  final BattleResult result;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Duration? duration;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  const Battle({
    required this.id,
    required this.attackerId,
    required this.attackerNickname,
    this.defenderId,
    this.defenderNickname,
    required this.territoryId,
    required this.territoryName,
    this.stepsBurnedByAttacker = 0,
    this.stepsBurnedByDefender = 0,
    this.attackPointsSpent = 0,
    this.shieldPointsAdded = 0,
    required this.initialShield,
    required this.currentShield,
    this.result = BattleResult.ongoing,
    required this.startedAt,
    this.endedAt,
    this.duration,
    required this.createdAt,
    required this.updatedAt,
  });

  // Computed properties
  bool get isOngoing => result == BattleResult.ongoing;
  bool get isFinished => endedAt != null;
  bool get attackerWon => result == BattleResult.attackerWin;
  bool get defenderWon => result == BattleResult.defenderWin;
  
  int get totalStepsBurned => stepsBurnedByAttacker + stepsBurnedByDefender;
  int get shieldDamage => initialShield - currentShield;
  double get shieldPercentageRemaining => currentShield / initialShield;
  
  Duration get currentDuration {
    final endTime = endedAt ?? DateTime.now();
    return endTime.difference(startedAt);
  }

  // Factory constructors
  factory Battle.fromFirestoreMap(Map<String, dynamic> map) {
    return Battle(
      id: map['id'] as String,
      attackerId: map['attacker_id'] as String,
      attackerNickname: map['attacker_nickname'] as String,
      defenderId: map['defender_id'] as String?,
      defenderNickname: map['defender_nickname'] as String?,
      territoryId: map['territory_id'] as String,
      territoryName: map['territory_name'] as String,
      stepsBurnedByAttacker: map['steps_burned_by_attacker'] as int? ?? 0,
      stepsBurnedByDefender: map['steps_burned_by_defender'] as int? ?? 0,
      attackPointsSpent: map['attack_points_spent'] as int? ?? 0,
      shieldPointsAdded: map['shield_points_added'] as int? ?? 0,
      initialShield: map['initial_shield'] as int,
      currentShield: map['current_shield'] as int,
      result: BattleResult.values.firstWhere(
        (e) => e.toString().split('.').last == map['result'] as String,
        orElse: () => BattleResult.ongoing,
      ),
      startedAt: (map['started_at'] as dynamic).toDate(),
      endedAt: map['ended_at'] != null ? (map['ended_at'] as dynamic).toDate() : null,
      duration: map['duration_seconds'] != null 
          ? Duration(seconds: map['duration_seconds'] as int)
          : null,
      createdAt: (map['created_at'] as dynamic).toDate(),
      updatedAt: (map['updated_at'] as dynamic).toDate(),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'attacker_id': attackerId,
      'attacker_nickname': attackerNickname,
      'defender_id': defenderId,
      'defender_nickname': defenderNickname,
      'territory_id': territoryId,
      'territory_name': territoryName,
      'steps_burned_by_attacker': stepsBurnedByAttacker,
      'steps_burned_by_defender': stepsBurnedByDefender,
      'attack_points_spent': attackPointsSpent,
      'shield_points_added': shieldPointsAdded,
      'initial_shield': initialShield,
      'current_shield': currentShield,
      'result': result.toString().split('.').last,
      'started_at': startedAt,
      'ended_at': endedAt,
      'duration_seconds': duration?.inSeconds,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Battle copyWith({
    String? id,
    String? attackerId,
    String? attackerNickname,
    String? defenderId,
    String? defenderNickname,
    String? territoryId,
    String? territoryName,
    int? stepsBurnedByAttacker,
    int? stepsBurnedByDefender,
    int? attackPointsSpent,
    int? shieldPointsAdded,
    int? initialShield,
    int? currentShield,
    BattleResult? result,
    DateTime? startedAt,
    DateTime? endedAt,
    Duration? duration,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Battle(
      id: id ?? this.id,
      attackerId: attackerId ?? this.attackerId,
      attackerNickname: attackerNickname ?? this.attackerNickname,
      defenderId: defenderId ?? this.defenderId,
      defenderNickname: defenderNickname ?? this.defenderNickname,
      territoryId: territoryId ?? this.territoryId,
      territoryName: territoryName ?? this.territoryName,
      stepsBurnedByAttacker: stepsBurnedByAttacker ?? this.stepsBurnedByAttacker,
      stepsBurnedByDefender: stepsBurnedByDefender ?? this.stepsBurnedByDefender,
      attackPointsSpent: attackPointsSpent ?? this.attackPointsSpent,
      shieldPointsAdded: shieldPointsAdded ?? this.shieldPointsAdded,
      initialShield: initialShield ?? this.initialShield,
      currentShield: currentShield ?? this.currentShield,
      result: result ?? this.result,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
