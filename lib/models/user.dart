class GameUser {
  final String id;
  final String nickname;
  final int totalSteps;
  final int attackPoints; // Accumulated attack points (100 steps = 1 attack point)
  final int shieldPoints; // Points available for defending (100 steps = 1 shield point)
  final int attacksUsedToday;
  final DateTime lastAttackReset; // For daily attack limit tracking
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // User statistics
  final int territoriesOwned;
  final int totalAttacksLaunched;
  final int totalDefensesWon;
  final int totalTerritoriesCaptured;
  
  // Settings
  final bool notificationsEnabled;
  final String? deviceToken; // For push notifications

  const GameUser({
    required this.id,
    required this.nickname,
    this.totalSteps = 0,
    this.attackPoints = 0,
    this.shieldPoints = 0,
    this.attacksUsedToday = 0,
    required this.lastAttackReset,
    required this.createdAt,
    required this.updatedAt,
    this.territoriesOwned = 0,
    this.totalAttacksLaunched = 0,
    this.totalDefensesWon = 0,
    this.totalTerritoriesCaptured = 0,
    this.notificationsEnabled = true,
    this.deviceToken,
  });

  // Computed properties
  bool get canAttackToday => attacksUsedToday < 3; // Default daily limit
  
  bool get needsAttackReset {
    final now = DateTime.now();
    final resetTime = DateTime(now.year, now.month, now.day);
    return lastAttackReset.isBefore(resetTime);
  }

  // Factory constructors
  factory GameUser.fromMap(Map<String, dynamic> map) {
    return GameUser(
      id: map['id'] as String,
      nickname: map['nickname'] as String,
      totalSteps: map['total_steps'] as int? ?? 0,
      attackPoints: map['attack_points'] as int? ?? 0,
      shieldPoints: map['shield_points'] as int? ?? 0,
      attacksUsedToday: map['attacks_used_today'] as int? ?? 0,
      lastAttackReset: DateTime.fromMillisecondsSinceEpoch(map['last_attack_reset'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      territoriesOwned: map['territories_owned'] as int? ?? 0,
      totalAttacksLaunched: map['total_attacks_launched'] as int? ?? 0,
      totalDefensesWon: map['total_defenses_won'] as int? ?? 0,
      totalTerritoriesCaptured: map['total_territories_captured'] as int? ?? 0,
      notificationsEnabled: (map['notifications_enabled'] as int?) == 1,
      deviceToken: map['device_token'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nickname': nickname,
      'total_steps': totalSteps,
      'attack_points': attackPoints,
      'shield_points': shieldPoints,
      'attacks_used_today': attacksUsedToday,
      'last_attack_reset': lastAttackReset.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'territories_owned': territoriesOwned,
      'total_attacks_launched': totalAttacksLaunched,
      'total_defenses_won': totalDefensesWon,
      'total_territories_captured': totalTerritoriesCaptured,
      'notifications_enabled': notificationsEnabled ? 1 : 0,
      'device_token': deviceToken,
    };
  }

  GameUser copyWith({
    String? id,
    String? nickname,
    int? totalSteps,
    int? attackPoints,
    int? shieldPoints,
    int? attacksUsedToday,
    DateTime? lastAttackReset,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? territoriesOwned,
    int? totalAttacksLaunched,
    int? totalDefensesWon,
    int? totalTerritoriesCaptured,
    bool? notificationsEnabled,
    String? deviceToken,
  }) {
    return GameUser(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      totalSteps: totalSteps ?? this.totalSteps,
      attackPoints: attackPoints ?? this.attackPoints,
      shieldPoints: shieldPoints ?? this.shieldPoints,
      attacksUsedToday: attacksUsedToday ?? this.attacksUsedToday,
      lastAttackReset: lastAttackReset ?? this.lastAttackReset,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      territoriesOwned: territoriesOwned ?? this.territoriesOwned,
      totalAttacksLaunched: totalAttacksLaunched ?? this.totalAttacksLaunched,
      totalDefensesWon: totalDefensesWon ?? this.totalDefensesWon,
      totalTerritoriesCaptured: totalTerritoriesCaptured ?? this.totalTerritoriesCaptured,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      deviceToken: deviceToken ?? this.deviceToken,
    );
  }
}
