import '../models/territory.dart';
import '../models/user_stats.dart';

class MockData {
  // Territories with runtime cooldowns → must use final, not const
  static final List<Territory> territories = [
    Territory(
      id: 'paris_001',
      name: 'Paris',
      owner: 'You',
      shieldLevel: 3,
      shieldMax: 5,
      status: TerritoryStatus.peaceful,
    ),
    Territory(
      id: 'tokyo_001',
      name: 'Tokyo',
      owner: 'ShadowStride',
      shieldLevel: 2,
      shieldMax: 5,
      status: TerritoryStatus.peaceful,
    ),
    Territory(
      id: 'bhutan_001',
      name: 'Bhutan',
      owner: null,
      shieldLevel: 1,
      shieldMax: 5,
      status: TerritoryStatus.peaceful,
    ),
    Territory(
      id: 'london_001',
      name: 'London',
      owner: 'WarriorQueen',
      shieldLevel: 4,
      shieldMax: 5,
      status: TerritoryStatus.underAttack,
    ),
    Territory(
      id: 'newyork_001',
      name: 'New York',
      owner: 'StepMaster',
      shieldLevel: 5,
      shieldMax: 5,
      status: TerritoryStatus.cooldown,
      cooldownEnd: DateTime.now().add(const Duration(hours: 23, minutes: 45)),
    ),
    Territory(
      id: 'sydney_001',
      name: 'Sydney',
      owner: 'FitnessGuru',
      shieldLevel: 3,
      shieldMax: 5,
      status: TerritoryStatus.peaceful,
    ),
    Territory(
      id: 'cairo_001',
      name: 'Cairo',
      owner: null,
      shieldLevel: 2,
      shieldMax: 5,
      status: TerritoryStatus.peaceful,
    ),
    Territory(
      id: 'moscow_001',
      name: 'Moscow',
      owner: 'IronWalker',
      shieldLevel: 1,
      shieldMax: 5,
      status: TerritoryStatus.underAttack,
    ),
    Territory(
      id: 'rio_001',
      name: 'Rio de Janeiro',
      owner: 'BeachRunner',
      shieldLevel: 4,
      shieldMax: 5,
      status: TerritoryStatus.peaceful,
    ),
    Territory(
      id: 'mumbai_001',
      name: 'Mumbai',
      owner: 'SpiceWarrior',
      shieldLevel: 2,
      shieldMax: 5,
      status: TerritoryStatus.peaceful,
    ),
    Territory(
      id: 'berlin_001',
      name: 'Berlin',
      owner: null,
      shieldLevel: 3,
      shieldMax: 5,
      status: TerritoryStatus.peaceful,
    ),
    Territory(
      id: 'toronto_001',
      name: 'Toronto',
      owner: 'MapleLeafHero',
      shieldLevel: 5,
      shieldMax: 5,
      status: TerritoryStatus.cooldown,
      cooldownEnd: DateTime.now().add(const Duration(hours: 12, minutes: 30)),
    ),
    Territory(
      id: 'dubai_001',
      name: 'Dubai',
      owner: 'DesertStorm',
      shieldLevel: 4,
      shieldMax: 5,
      status: TerritoryStatus.peaceful,
    ),
    Territory(
      id: 'singapore_001',
      name: 'Singapore',
      owner: null,
      shieldLevel: 1,
      shieldMax: 5,
      status: TerritoryStatus.peaceful,
    ),
    Territory(
      id: 'stockholm_001',
      name: 'Stockholm',
      owner: 'NordicViking',
      shieldLevel: 3,
      shieldMax: 5,
      status: TerritoryStatus.peaceful,
    ),
    Territory(
      id: 'capetown_001',
      name: 'Cape Town',
      owner: 'SafariRunner',
      shieldLevel: 2,
      shieldMax: 5,
      status: TerritoryStatus.underAttack,
    ),
    Territory(
      id: 'seoul_001',
      name: 'Seoul',
      owner: 'KPopStepper',
      shieldLevel: 5,
      shieldMax: 5,
      status: TerritoryStatus.peaceful,
    ),
    Territory(
      id: 'mexico_001',
      name: 'Mexico City',
      owner: null,
      shieldLevel: 2,
      shieldMax: 5,
      status: TerritoryStatus.peaceful,
    ),
    Territory(
      id: 'istanbul_001',
      name: 'Istanbul',
      owner: 'BridgeWalker',
      shieldLevel: 3,
      shieldMax: 5,
      status: TerritoryStatus.peaceful,
    ),
    Territory(
      id: 'bangkok_001',
      name: 'Bangkok',
      owner: 'TempleGuardian',
      shieldLevel: 4,
      shieldMax: 5,
      status: TerritoryStatus.peaceful,
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
      owner: hasOwner ? playerNames[ownerIndex] : null,
      shieldLevel: shieldLevel,
      shieldMax: 5,
      status: statuses[statusIndex],
      cooldownEnd: statuses[statusIndex] == TerritoryStatus.cooldown
          ? DateTime.now().add(Duration(hours: 1 + (random % 24)))
          : null,
    );
  }

  // Get user's owned territories
  static List<Territory> getUserTerritories() {
    return territories.where((t) => t.owner == 'You').toList();
  }

  // Get attackable territories
  static List<Territory> getAttackableTerritories() {
    return territories.where((t) =>
        t.owner != 'You' &&
        t.status == TerritoryStatus.peaceful &&
        t.canBeAttacked).toList();
  }

  // Get territories under attack
  static List<Territory> getTerritoriesUnderAttack() {
    return territories.where((t) => t.status == TerritoryStatus.underAttack).toList();
  }

  // Get unowned territories
  static List<Territory> getUnownedTerritories() {
    return territories.where((t) => t.owner == null).toList();
  }
}
