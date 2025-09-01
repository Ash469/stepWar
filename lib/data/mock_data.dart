import '../models/territory.dart';
import '../models/user_stats.dart';

class MockData {
  // Territories with runtime cooldowns → must use final, not const
  static final List<Territory> territories = [
    Territory(
      id: 'paris_001',
      name: 'Paris',
      ownerNickname: 'You',
      currentShield: 3,
      maxShield: 5,
      status: TerritoryStatus.peaceful,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now(),
    ),
    Territory(
      id: 'tokyo_001',
      name: 'Tokyo',
      ownerNickname: 'ShadowStride',
      currentShield: 2,
      maxShield: 5,
      status: TerritoryStatus.peaceful,
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
      updatedAt: DateTime.now(),
    ),
    Territory(
      id: 'bhutan_001',
      name: 'Bhutan',
      ownerNickname: null,
      currentShield: 1,
      maxShield: 5,
      status: TerritoryStatus.peaceful,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now(),
    ),
    Territory(
      id: 'london_001',
      name: 'London',
      ownerNickname: 'WarriorQueen',
      currentShield: 4,
      maxShield: 5,
      status: TerritoryStatus.underAttack,
      createdAt: DateTime.now().subtract(const Duration(days: 12)),
      updatedAt: DateTime.now(),
    ),
    Territory(
      id: 'newyork_001',
      name: 'New York',
      ownerNickname: 'StepMaster',
      currentShield: 5,
      maxShield: 5,
      status: TerritoryStatus.cooldown,
      cooldownUntil: DateTime.now().add(const Duration(hours: 23, minutes: 45)),
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
      updatedAt: DateTime.now(),
    ),
    Territory(
      id: 'sydney_001',
      name: 'Sydney',
      ownerNickname: 'FitnessGuru',
      currentShield: 3,
      maxShield: 5,
      status: TerritoryStatus.peaceful,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      updatedAt: DateTime.now(),
    ),
    Territory(
      id: 'cairo_001',
      name: 'Cairo',
      ownerNickname: null,
      currentShield: 2,
      maxShield: 5,
      status: TerritoryStatus.peaceful,
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
      updatedAt: DateTime.now(),
    ),
    Territory(
      id: 'moscow_001',
      name: 'Moscow',
      ownerNickname: 'IronWalker',
      currentShield: 1,
      maxShield: 5,
      status: TerritoryStatus.underAttack,
      createdAt: DateTime.now().subtract(const Duration(days: 9)),
      updatedAt: DateTime.now(),
    ),
    Territory(
      id: 'rio_001',
      name: 'Rio de Janeiro',
      ownerNickname: 'BeachRunner',
      currentShield: 4,
      maxShield: 5,
      status: TerritoryStatus.peaceful,
      createdAt: DateTime.now().subtract(const Duration(days: 11)),
      updatedAt: DateTime.now(),
    ),
    Territory(
      id: 'mumbai_001',
      name: 'Mumbai',
      ownerNickname: 'SpiceWarrior',
      currentShield: 2,
      maxShield: 5,
      status: TerritoryStatus.peaceful,
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      updatedAt: DateTime.now(),
    ),
    Territory(
      id: 'berlin_001',
      name: 'Berlin',
      ownerNickname: null,
      currentShield: 3,
      maxShield: 5,
      status: TerritoryStatus.peaceful,
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
      updatedAt: DateTime.now(),
    ),
    Territory(
      id: 'toronto_001',
      name: 'Toronto',
      ownerNickname: 'MapleLeafHero',
      currentShield: 5,
      maxShield: 5,
      status: TerritoryStatus.cooldown,
      cooldownUntil: DateTime.now().add(const Duration(hours: 12, minutes: 30)),
      createdAt: DateTime.now().subtract(const Duration(days: 13)),
      updatedAt: DateTime.now(),
    ),
    Territory(
      id: 'dubai_001',
      name: 'Dubai',
      ownerNickname: 'DesertStorm',
      currentShield: 4,
      maxShield: 5,
      status: TerritoryStatus.peaceful,
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
      updatedAt: DateTime.now(),
    ),
    Territory(
      id: 'singapore_001',
      name: 'Singapore',
      ownerNickname: null,
      currentShield: 1,
      maxShield: 5,
      status: TerritoryStatus.peaceful,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now(),
    ),
    Territory(
      id: 'stockholm_001',
      name: 'Stockholm',
      ownerNickname: 'NordicViking',
      currentShield: 3,
      maxShield: 5,
      status: TerritoryStatus.peaceful,
      createdAt: DateTime.now().subtract(const Duration(days: 14)),
      updatedAt: DateTime.now(),
    ),
    Territory(
      id: 'capetown_001',
      name: 'Cape Town',
      ownerNickname: 'SafariRunner',
      currentShield: 2,
      maxShield: 5,
      status: TerritoryStatus.underAttack,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      updatedAt: DateTime.now(),
    ),
    Territory(
      id: 'seoul_001',
      name: 'Seoul',
      ownerNickname: 'KPopStepper',
      currentShield: 5,
      maxShield: 5,
      status: TerritoryStatus.peaceful,
      createdAt: DateTime.now().subtract(const Duration(days: 16)),
      updatedAt: DateTime.now(),
    ),
    Territory(
      id: 'mexico_001',
      name: 'Mexico City',
      ownerNickname: null,
      currentShield: 2,
      maxShield: 5,
      status: TerritoryStatus.peaceful,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now(),
    ),
    Territory(
      id: 'istanbul_001',
      name: 'Istanbul',
      ownerNickname: 'BridgeWalker',
      currentShield: 3,
      maxShield: 5,
      status: TerritoryStatus.peaceful,
      createdAt: DateTime.now().subtract(const Duration(days: 9)),
      updatedAt: DateTime.now(),
    ),
    Territory(
      id: 'bangkok_001',
      name: 'Bangkok',
      ownerNickname: 'TempleGuardian',
      currentShield: 4,
      maxShield: 5,
      status: TerritoryStatus.peaceful,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now(),
    ),
  ];

  // default user stats → can be const
  static const UserStats defaultUserStats = UserStats(
    dailySteps: 8547,
    totalSteps: 125430,
    attackPoints: 85,
    shieldPoints: 85,
    territoriesOwned: 1,
    battlesWon: 12,
    battlesLost: 3,
    attacksRemaining: 2,
  );

  static List<String> get playerNames => [
        'ShadowStride',
        'WarriorQueen',
        'StepMaster',
        'FitnessGuru',
        'IronWalker',
        'BeachRunner',
        'SpiceWarrior',
        'MapleLeafHero',
        'DesertStorm',
        'NordicViking',
        'SafariRunner',
        'KPopStepper',
        'BridgeWalker',
        'TempleGuardian',
        'MountainClimber',
        'OceanWalker',
        'CityRunner',
        'ForestHiker',
        'DesertNomad',
        'ArcticExplorer',
      ];

  static List<String> get territoryNames => [
        'Paris',
        'Tokyo',
        'London',
        'New York',
        'Sydney',
        'Cairo',
        'Moscow',
        'Rio de Janeiro',
        'Mumbai',
        'Berlin',
        'Toronto',
        'Dubai',
        'Singapore',
        'Stockholm',
        'Cape Town',
        'Seoul',
        'Mexico City',
        'Istanbul',
        'Bangkok',
        'Bhutan',
        'Reykjavik',
        'Oslo',
        'Helsinki',
        'Copenhagen',
        'Amsterdam',
        'Brussels',
        'Vienna',
        'Prague',
        'Budapest',
        'Warsaw',
        'Lisbon',
        'Madrid',
        'Rome',
        'Athens',
        'Zurich',
        'Geneva',
        'Monaco',
        'Luxembourg',
        'Dublin',
        'Edinburgh',
        'Cardiff',
        'Belfast',
        'Manchester',
        'Liverpool',
        'Birmingham',
        'Glasgow',
        'Aberdeen',
        'York',
        'Bath',
        'Canterbury',
      ];

  // Generate random territory
  static Territory generateRandomTerritory() {
    final random = DateTime.now().millisecondsSinceEpoch;
    final nameIndex = random % territoryNames.length;
    final hasOwner = (random % 3) != 0; // 2/3 chance of having owner
    final ownerIndex = random % playerNames.length;
    final shieldLevel = 1 + (random % 5);
    final statusIndex = random % 3;

    final statuses = [
      TerritoryStatus.peaceful,
      TerritoryStatus.underAttack,
      TerritoryStatus.cooldown,
    ];

    return Territory(
      id:
          '${territoryNames[nameIndex].toLowerCase().replaceAll(' ', '_')}_${random % 1000}',
      name: territoryNames[nameIndex],
      ownerNickname: hasOwner ? playerNames[ownerIndex] : null,
      currentShield: shieldLevel,
      maxShield: 5,
      status: statuses[statusIndex],
      cooldownUntil: statuses[statusIndex] == TerritoryStatus.cooldown
          ? DateTime.now().add(Duration(hours: 1 + (random % 24)))
          : null,
      createdAt: DateTime.now().subtract(Duration(days: random % 30)),
      updatedAt: DateTime.now(),
    );
  }

  // Get user's owned territories
  static List<Territory> getUserTerritories() {
    return territories.where((t) => t.ownerNickname == 'You').toList();
  }

  // Get attackable territories
  static List<Territory> getAttackableTerritories() {
    return territories.where((t) =>
        t.ownerNickname != 'You' &&
        t.status == TerritoryStatus.peaceful &&
        t.canBeAttacked).toList();
  }

  // Get territories under attack
  static List<Territory> getTerritoriesUnderAttack() {
    return territories.where((t) => t.status == TerritoryStatus.underAttack).toList();
  }

  // Get unowned territories
  static List<Territory> getUnownedTerritories() {
    return territories.where((t) => t.ownerNickname == null).toList();
  }
}
