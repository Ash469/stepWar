class GameConfig {
  final String id;
  final int stepsPerAttackPoint;
  final int attackPointsPerShieldHit;
  final int stepsPerShieldPoint;

  // Daily Limits (from game rules: 3.2)
  final int dailyAttackLimit;

  // Territory Settings (from game rules: 3.1, 3.5)
  final int newUserStartingShieldMin;
  final int newUserStartingShieldMax;
  final int baseShieldOnCapture;
  final int cooldownHours;
  
  // Territory Generation
  final int maxTerritories;
  final bool allowUnownedTerritories;

  final DateTime createdAt;
  final DateTime updatedAt;

  const GameConfig({
    required this.id,
    this.stepsPerAttackPoint = 100,
    this.attackPointsPerShieldHit = 10,
    this.stepsPerShieldPoint = 100,
    this.dailyAttackLimit = 3,
    this.newUserStartingShieldMin = 1,
    this.newUserStartingShieldMax = 2,
    this.baseShieldOnCapture = 1,
    this.cooldownHours = 24,
    this.maxTerritories = 100,
    this.allowUnownedTerritories = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // Computed properties based on the step economy rules
  int get stepsPerShieldHit => stepsPerAttackPoint * attackPointsPerShieldHit; 
  
  Duration get cooldownDuration => Duration(hours: cooldownHours);

  // Factory constructors
  factory GameConfig.defaultConfig() {
    final now = DateTime.now();
    return GameConfig(
      id: 'default',
      createdAt: now,
      updatedAt: now,
    );
  }

  factory GameConfig.fromMap(Map<String, dynamic> map) {
    return GameConfig(
      id: map['id'] as String,
      stepsPerAttackPoint: map['steps_per_attack_point'] as int? ?? 100,
      attackPointsPerShieldHit: map['attack_points_per_shield_hit'] as int? ?? 10,
      stepsPerShieldPoint: map['steps_per_shield_point'] as int? ?? 100,
      dailyAttackLimit: map['daily_attack_limit'] as int? ?? 3,
      newUserStartingShieldMin: map['new_user_starting_shield_min'] as int? ?? 1,
      newUserStartingShieldMax: map['new_user_starting_shield_max'] as int? ?? 2,
      baseShieldOnCapture: map['base_shield_on_capture'] as int? ?? 1,
      cooldownHours: map['cooldown_hours'] as int? ?? 24,
      maxTerritories: map['max_territories'] as int? ?? 100,
      allowUnownedTerritories: (map['allow_unowned_territories'] as int?) != 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  // Firestore-specific factory constructor
  factory GameConfig.fromFirestoreMap(Map<String, dynamic> map) {
    return GameConfig(
      id: map['id'] as String,
      stepsPerAttackPoint: map['steps_per_attack_point'] as int? ?? 100,
      attackPointsPerShieldHit: map['attack_points_per_shield_hit'] as int? ?? 10,
      stepsPerShieldPoint: map['steps_per_shield_point'] as int? ?? 100,
      dailyAttackLimit: map['daily_attack_limit'] as int? ?? 3,
      newUserStartingShieldMin: map['new_user_starting_shield_min'] as int? ?? 1,
      newUserStartingShieldMax: map['new_user_starting_shield_max'] as int? ?? 2,
      baseShieldOnCapture: map['base_shield_on_capture'] as int? ?? 1,
      cooldownHours: map['cooldown_hours'] as int? ?? 24,
      maxTerritories: map['max_territories'] as int? ?? 100,
      allowUnownedTerritories: map['allow_unowned_territories'] as bool? ?? true,
      createdAt: (map['created_at'] as dynamic).toDate(),
      updatedAt: (map['updated_at'] as dynamic).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'steps_per_attack_point': stepsPerAttackPoint,
      'attack_points_per_shield_hit': attackPointsPerShieldHit,
      'steps_per_shield_point': stepsPerShieldPoint,
      'daily_attack_limit': dailyAttackLimit,
      'new_user_starting_shield_min': newUserStartingShieldMin,
      'new_user_starting_shield_max': newUserStartingShieldMax,
      'base_shield_on_capture': baseShieldOnCapture,
      'cooldown_hours': cooldownHours,
      'max_territories': maxTerritories,
      'allow_unowned_territories': allowUnownedTerritories ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  // Firestore-specific map (uses Timestamp instead of milliseconds)
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'steps_per_attack_point': stepsPerAttackPoint,
      'attack_points_per_shield_hit': attackPointsPerShieldHit,
      'steps_per_shield_point': stepsPerShieldPoint,
      'daily_attack_limit': dailyAttackLimit,
      'new_user_starting_shield_min': newUserStartingShieldMin,
      'new_user_starting_shield_max': newUserStartingShieldMax,
      'base_shield_on_capture': baseShieldOnCapture,
      'cooldown_hours': cooldownHours,
      'max_territories': maxTerritories,
      'allow_unowned_territories': allowUnownedTerritories,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  GameConfig copyWith({
    String? id,
    int? stepsPerAttackPoint,
    int? attackPointsPerShieldHit,
    int? stepsPerShieldPoint,
    int? dailyAttackLimit,
    int? newUserStartingShieldMin,
    int? newUserStartingShieldMax,
    int? baseShieldOnCapture,
    int? cooldownHours,
    int? maxTerritories,
    bool? allowUnownedTerritories,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GameConfig(
      id: id ?? this.id,
      stepsPerAttackPoint: stepsPerAttackPoint ?? this.stepsPerAttackPoint,
      attackPointsPerShieldHit: attackPointsPerShieldHit ?? this.attackPointsPerShieldHit,
      stepsPerShieldPoint: stepsPerShieldPoint ?? this.stepsPerShieldPoint,
      dailyAttackLimit: dailyAttackLimit ?? this.dailyAttackLimit,
      newUserStartingShieldMin: newUserStartingShieldMin ?? this.newUserStartingShieldMin,
      newUserStartingShieldMax: newUserStartingShieldMax ?? this.newUserStartingShieldMax,
      baseShieldOnCapture: baseShieldOnCapture ?? this.baseShieldOnCapture,
      cooldownHours: cooldownHours ?? this.cooldownHours,
      maxTerritories: maxTerritories ?? this.maxTerritories,
      allowUnownedTerritories: allowUnownedTerritories ?? this.allowUnownedTerritories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
