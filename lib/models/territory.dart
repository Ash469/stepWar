enum TerritoryStatus {
  peaceful,
  underAttack,
  cooldown,
}

class Territory {
  final String id;
  final String name;
  final String? ownerId; // null if unowned
  final String? ownerNickname; // cached for performance
  final int currentShield;
  final int maxShield;
  final TerritoryStatus status;
  final DateTime? cooldownUntil; // null if not in cooldown
  final String? attackerId; // null if not under attack
  final DateTime? attackStarted; // when current attack began
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Base shield when territory is captured (configurable, default 1-2)
  final int baseShieldOnCapture;
  
  // Geographic info (for future map integration)
  final double? latitude;
  final double? longitude;

  const Territory({
    required this.id,
    required this.name,
    this.ownerId,
    this.ownerNickname,
    required this.currentShield,
    required this.maxShield,
    required this.status,
    this.cooldownUntil,
    this.attackerId,
    this.attackStarted,
    required this.createdAt,
    required this.updatedAt,
    this.baseShieldOnCapture = 1,
    this.latitude,
    this.longitude,
  });

  // Getters for computed properties
  bool get isOwned => ownerId != null;
  bool get isUnderAttack => status == TerritoryStatus.underAttack;
  bool get isInCooldown => status == TerritoryStatus.cooldown;
  bool get canBeAttacked => status == TerritoryStatus.peaceful && !isInCooldown;
  
  bool get isCooldownExpired {
    if (cooldownUntil == null) return true;
    return DateTime.now().isAfter(cooldownUntil!);
  }
  
  double get shieldPercentage => currentShield / maxShield;
  
  // Legacy getter for backward compatibility
  String? get owner => ownerNickname;
  int get shieldLevel => currentShield;
  int get shieldMax => maxShield;
  DateTime? get cooldownEnd => cooldownUntil;
  bool get isUnowned => !isOwned;

  // Factory constructors
  factory Territory.fromMap(Map<String, dynamic> map) {
    return Territory(
      id: map['id'] as String,
      name: map['name'] as String,
      ownerId: map['owner_id'] as String?,
      ownerNickname: map['owner_nickname'] as String?,
      currentShield: map['current_shield'] as int,
      maxShield: map['max_shield'] as int,
      status: TerritoryStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'] as String,
      ),
      cooldownUntil: map['cooldown_until'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['cooldown_until'] as int)
          : null,
      attackerId: map['attacker_id'] as String?,
      attackStarted: map['attack_started'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['attack_started'] as int)
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      baseShieldOnCapture: map['base_shield_on_capture'] as int? ?? 1,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'owner_id': ownerId,
      'owner_nickname': ownerNickname,
      'current_shield': currentShield,
      'max_shield': maxShield,
      'status': status.toString().split('.').last,
      'cooldown_until': cooldownUntil?.millisecondsSinceEpoch,
      'attacker_id': attackerId,
      'attack_started': attackStarted?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'base_shield_on_capture': baseShieldOnCapture,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  Territory copyWith({
    String? id,
    String? name,
    String? ownerId,
    String? ownerNickname,
    int? currentShield,
    int? maxShield,
    TerritoryStatus? status,
    DateTime? cooldownUntil,
    String? attackerId,
    DateTime? attackStarted,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? baseShieldOnCapture,
    double? latitude,
    double? longitude,
    bool clearOwner = false,
    bool clearAttacker = false,
    bool clearCooldown = false,
  }) {
    return Territory(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: clearOwner ? null : (ownerId ?? this.ownerId),
      ownerNickname: clearOwner ? null : (ownerNickname ?? this.ownerNickname),
      currentShield: currentShield ?? this.currentShield,
      maxShield: maxShield ?? this.maxShield,
      status: status ?? this.status,
      cooldownUntil: clearCooldown ? null : (cooldownUntil ?? this.cooldownUntil),
      attackerId: clearAttacker ? null : (attackerId ?? this.attackerId),
      attackStarted: clearAttacker ? null : (attackStarted ?? this.attackStarted),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      baseShieldOnCapture: baseShieldOnCapture ?? this.baseShieldOnCapture,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

