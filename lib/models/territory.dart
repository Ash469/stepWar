enum TerritoryStatus {
  peaceful,
  underAttack,
  cooldown,
}

class Territory {
  final String id;
  final String name;
  final String? owner;
  final int shieldLevel;
  final int shieldMax;
  final TerritoryStatus status;
  final DateTime? cooldownEnd;

  const Territory({
    required this.id,
    required this.name,
    this.owner,
    required this.shieldLevel,
    required this.shieldMax,
    required this.status,
    this.cooldownEnd,
  });

  Territory copyWith({
    String? id,
    String? name,
    String? owner,
    int? shieldLevel,
    int? shieldMax,
    TerritoryStatus? status,
    DateTime? cooldownEnd,
  }) {
    return Territory(
      id: id ?? this.id,
      name: name ?? this.name,
      owner: owner ?? this.owner,
      shieldLevel: shieldLevel ?? this.shieldLevel,
      shieldMax: shieldMax ?? this.shieldMax,
      status: status ?? this.status,
      cooldownEnd: cooldownEnd ?? this.cooldownEnd,
    );
  }

  double get shieldPercentage => shieldLevel / shieldMax;
  
  bool get isUnowned => owner == null;
  
  bool get canBeAttacked => 
      status == TerritoryStatus.peaceful && 
      (cooldownEnd == null || DateTime.now().isAfter(cooldownEnd!));
}

