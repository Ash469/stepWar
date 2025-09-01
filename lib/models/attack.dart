enum AttackStatus {
  active,
  completed,
  failed,
  abandoned,
}

class Attack {
  final String id;
  final String attackerId;
  final String attackerNickname;
  final String territoryId;
  final String territoryName;
  final String? defenderId; // null if territory is unowned
  final String? defenderNickname;
  final AttackStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  
  // Attack progress
  final int attackPointsSpent; // Total attack points committed
  final int shieldPointsDefended; // Shield points defender has added
  final int initialShield; // Shield level when attack started
  final int finalShield; // Shield level when attack ended (0 if successful)
  
  // Results
  final bool successful; // True if attacker captured the territory
  final int stepsBurned; // Total steps converted to attack points
  
  const Attack({
    required this.id,
    required this.attackerId,
    required this.attackerNickname,
    required this.territoryId,
    required this.territoryName,
    this.defenderId,
    this.defenderNickname,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.attackPointsSpent = 0,
    this.shieldPointsDefended = 0,
    required this.initialShield,
    this.finalShield = 0,
    this.successful = false,
    this.stepsBurned = 0,
  });

  // Computed properties
  Duration get duration {
    final endTime = completedAt ?? DateTime.now();
    return endTime.difference(startedAt);
  }
  
  bool get isActive => status == AttackStatus.active;
  bool get isCompleted => status == AttackStatus.completed;
  
  int get netShieldChange => attackPointsSpent - shieldPointsDefended;
  
  // Factory constructors
  factory Attack.fromMap(Map<String, dynamic> map) {
    return Attack(
      id: map['id'] as String,
      attackerId: map['attacker_id'] as String,
      attackerNickname: map['attacker_nickname'] as String,
      territoryId: map['territory_id'] as String,
      territoryName: map['territory_name'] as String,
      defenderId: map['defender_id'] as String?,
      defenderNickname: map['defender_nickname'] as String?,
      status: AttackStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'] as String,
      ),
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int),
      completedAt: map['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int)
          : null,
      attackPointsSpent: map['attack_points_spent'] as int? ?? 0,
      shieldPointsDefended: map['shield_points_defended'] as int? ?? 0,
      initialShield: map['initial_shield'] as int,
      finalShield: map['final_shield'] as int? ?? 0,
      successful: (map['successful'] as int?) == 1,
      stepsBurned: map['steps_burned'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'attacker_id': attackerId,
      'attacker_nickname': attackerNickname,
      'territory_id': territoryId,
      'territory_name': territoryName,
      'defender_id': defenderId,
      'defender_nickname': defenderNickname,
      'status': status.toString().split('.').last,
      'started_at': startedAt.millisecondsSinceEpoch,
      'completed_at': completedAt?.millisecondsSinceEpoch,
      'attack_points_spent': attackPointsSpent,
      'shield_points_defended': shieldPointsDefended,
      'initial_shield': initialShield,
      'final_shield': finalShield,
      'successful': successful ? 1 : 0,
      'steps_burned': stepsBurned,
    };
  }

  Attack copyWith({
    String? id,
    String? attackerId,
    String? attackerNickname,
    String? territoryId,
    String? territoryName,
    String? defenderId,
    String? defenderNickname,
    AttackStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    int? attackPointsSpent,
    int? shieldPointsDefended,
    int? initialShield,
    int? finalShield,
    bool? successful,
    int? stepsBurned,
  }) {
    return Attack(
      id: id ?? this.id,
      attackerId: attackerId ?? this.attackerId,
      attackerNickname: attackerNickname ?? this.attackerNickname,
      territoryId: territoryId ?? this.territoryId,
      territoryName: territoryName ?? this.territoryName,
      defenderId: defenderId ?? this.defenderId,
      defenderNickname: defenderNickname ?? this.defenderNickname,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      attackPointsSpent: attackPointsSpent ?? this.attackPointsSpent,
      shieldPointsDefended: shieldPointsDefended ?? this.shieldPointsDefended,
      initialShield: initialShield ?? this.initialShield,
      finalShield: finalShield ?? this.finalShield,
      successful: successful ?? this.successful,
      stepsBurned: stepsBurned ?? this.stepsBurned,
    );
  }
}
