import 'dart:async';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/territory.dart';
import '../models/user.dart';
import '../models/attack.dart';
import '../models/game_config.dart';

class DatabaseHelper {
  static const String _databaseName = 'stepwars.db';
  static const int _databaseVersion = 1;
  
  static Database? _database;
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        nickname TEXT NOT NULL UNIQUE,
        total_steps INTEGER NOT NULL DEFAULT 0,
        attack_points INTEGER NOT NULL DEFAULT 0,
        shield_points INTEGER NOT NULL DEFAULT 0,
        attacks_used_today INTEGER NOT NULL DEFAULT 0,
        last_attack_reset INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        territories_owned INTEGER NOT NULL DEFAULT 0,
        total_attacks_launched INTEGER NOT NULL DEFAULT 0,
        total_defenses_won INTEGER NOT NULL DEFAULT 0,
        total_territories_captured INTEGER NOT NULL DEFAULT 0,
        notifications_enabled INTEGER NOT NULL DEFAULT 1,
        device_token TEXT
      )
    ''');

    // Territories table
    await db.execute('''
      CREATE TABLE territories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        owner_id TEXT,
        owner_nickname TEXT,
        current_shield INTEGER NOT NULL,
        max_shield INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'peaceful',
        cooldown_until INTEGER,
        attacker_id TEXT,
        attack_started INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        base_shield_on_capture INTEGER NOT NULL DEFAULT 1,
        latitude REAL,
        longitude REAL,
        FOREIGN KEY (owner_id) REFERENCES users (id),
        FOREIGN KEY (attacker_id) REFERENCES users (id)
      )
    ''');

    // Attacks table
    await db.execute('''
      CREATE TABLE attacks (
        id TEXT PRIMARY KEY,
        attacker_id TEXT NOT NULL,
        attacker_nickname TEXT NOT NULL,
        territory_id TEXT NOT NULL,
        territory_name TEXT NOT NULL,
        defender_id TEXT,
        defender_nickname TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        started_at INTEGER NOT NULL,
        completed_at INTEGER,
        attack_points_spent INTEGER NOT NULL DEFAULT 0,
        shield_points_defended INTEGER NOT NULL DEFAULT 0,
        initial_shield INTEGER NOT NULL,
        final_shield INTEGER NOT NULL DEFAULT 0,
        successful INTEGER NOT NULL DEFAULT 0,
        steps_burned INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (attacker_id) REFERENCES users (id),
        FOREIGN KEY (territory_id) REFERENCES territories (id),
        FOREIGN KEY (defender_id) REFERENCES users (id)
      )
    ''');

    // Game configuration table
    await db.execute('''
      CREATE TABLE game_config (
        id TEXT PRIMARY KEY,
        steps_per_attack_point INTEGER NOT NULL DEFAULT 100,
        attack_points_per_shield_hit INTEGER NOT NULL DEFAULT 10,
        steps_per_shield_point INTEGER NOT NULL DEFAULT 100,
        daily_attack_limit INTEGER NOT NULL DEFAULT 3,
        new_user_starting_shield_min INTEGER NOT NULL DEFAULT 1,
        new_user_starting_shield_max INTEGER NOT NULL DEFAULT 2,
        base_shield_on_capture INTEGER NOT NULL DEFAULT 1,
        cooldown_hours INTEGER NOT NULL DEFAULT 24,
        max_territories INTEGER NOT NULL DEFAULT 100,
        allow_unowned_territories INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_territories_owner_id ON territories (owner_id)');
    await db.execute('CREATE INDEX idx_territories_status ON territories (status)');
    await db.execute('CREATE INDEX idx_attacks_attacker_id ON attacks (attacker_id)');
    await db.execute('CREATE INDEX idx_attacks_territory_id ON attacks (territory_id)');
    await db.execute('CREATE INDEX idx_attacks_status ON attacks (status)');
    
    // Insert default game configuration
    await _insertDefaultConfig(db);
    
    // Insert initial territories
    await _insertInitialTerritories(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here when version increases
    // For now, we'll just recreate everything
    if (oldVersion < newVersion) {
      await db.execute('DROP TABLE IF EXISTS attacks');
      await db.execute('DROP TABLE IF EXISTS territories');
      await db.execute('DROP TABLE IF EXISTS users');
      await db.execute('DROP TABLE IF EXISTS game_config');
      await _onCreate(db, newVersion);
    }
  }

  Future<void> _insertDefaultConfig(Database db) async {
    final config = GameConfig.defaultConfig();
    await db.insert('game_config', config.toMap());
  }

  Future<void> _insertInitialTerritories(Database db) async {
    final territories = [
      'New York', 'London', 'Tokyo', 'Paris', 'Sydney', 'Mumbai', 'Cairo',
      'Rio de Janeiro', 'Moscow', 'Beijing', 'Los Angeles', 'Berlin',
      'Rome', 'Madrid', 'Bangkok', 'Singapore', 'Hong Kong', 'Dubai',
      'Toronto', 'Mexico City', 'Seoul', 'Amsterdam', 'Stockholm', 'Vienna',
      'Prague', 'Warsaw', 'Budapest', 'Zurich', 'Brussels', 'Copenhagen',
      'Helsinki', 'Oslo', 'Lisbon', 'Athens', 'Istanbul', 'Tel Aviv',
      'Casablanca', 'Lagos', 'Nairobi', 'Cape Town', 'Johannesburg',
      'Melbourne', 'Perth', 'Auckland', 'Wellington', 'Vancouver',
      'Montreal', 'Chicago', 'Miami', 'San Francisco'
    ];

    final uuid = Uuid();
    final now = DateTime.now();
    final random = Random();

    for (final territoryName in territories) {
      final territory = Territory(
        id: uuid.v4(),
        name: territoryName,
        currentShield: 1 + random.nextInt(2), // 1-2 shields for unowned territories
        maxShield: 5 + random.nextInt(6), // 5-10 max shield for variety
        status: TerritoryStatus.peaceful,
        createdAt: now,
        updatedAt: now,
      );
      
      await db.insert('territories', territory.toMap());
    }
  }

  // User operations
  Future<String> createUser(String nickname) async {
    final db = await database;
    final uuid = Uuid();
    final now = DateTime.now();
    final userId = uuid.v4();
    
    final user = GameUser(
      id: userId,
      nickname: nickname,
      lastAttackReset: now,
      createdAt: now,
      updatedAt: now,
    );
    
    await db.insert('users', user.toMap());
    
    // Assign a random unowned territory to new user if available
    await _assignRandomTerritoryToNewUser(userId, nickname);
    
    return userId;
  }

  Future<void> _assignRandomTerritoryToNewUser(String userId, String nickname) async {
    final db = await database;
    final config = await getGameConfig();
    
    // Find unowned territories
    final unownedTerritories = await db.query(
      'territories',
      where: 'owner_id IS NULL AND status = ?',
      whereArgs: ['peaceful'],
    );
    
    if (unownedTerritories.isNotEmpty && config.allowUnownedTerritories) {
      final random = Random();
      final selectedTerritory = unownedTerritories[random.nextInt(unownedTerritories.length)];
      
      // Assign territory to user with low shields (1-2 hits)
      final newShield = config.newUserStartingShieldMin + 
          random.nextInt(config.newUserStartingShieldMax - config.newUserStartingShieldMin + 1);
      
      await db.update(
        'territories',
        {
          'owner_id': userId,
          'owner_nickname': nickname,
          'current_shield': newShield,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [selectedTerritory['id']],
      );
      
      // Update user's territory count
      await db.update(
        'users',
        {
          'territories_owned': 1,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [userId],
      );
    }
  }

  Future<GameUser?> getUser(String userId) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );
    
    if (maps.isNotEmpty) {
      return GameUser.fromMap(maps.first);
    }
    return null;
  }

  Future<GameUser?> getUserByNickname(String nickname) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'nickname = ?',
      whereArgs: [nickname],
    );
    
    if (maps.isNotEmpty) {
      return GameUser.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateUser(GameUser user) async {
    final db = await database;
    await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  // Territory operations
  Future<List<Territory>> getAllTerritories() async {
    final db = await database;
    final maps = await db.query('territories', orderBy: 'name ASC');
    return maps.map((map) => Territory.fromMap(map)).toList();
  }

  Future<List<Territory>> getUserTerritories(String userId) async {
    final db = await database;
    final maps = await db.query(
      'territories',
      where: 'owner_id = ?',
      whereArgs: [userId],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Territory.fromMap(map)).toList();
  }

  Future<Territory?> getTerritory(String territoryId) async {
    final db = await database;
    final maps = await db.query(
      'territories',
      where: 'id = ?',
      whereArgs: [territoryId],
    );
    
    if (maps.isNotEmpty) {
      return Territory.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateTerritory(Territory territory) async {
    final db = await database;
    await db.update(
      'territories',
      territory.toMap(),
      where: 'id = ?',
      whereArgs: [territory.id],
    );
  }

  // Attack operations
  Future<String> createAttack(Attack attack) async {
    final db = await database;
    await db.insert('attacks', attack.toMap());
    return attack.id;
  }

  Future<Attack?> getActiveAttackForTerritory(String territoryId) async {
    final db = await database;
    final maps = await db.query(
      'attacks',
      where: 'territory_id = ? AND status = ?',
      whereArgs: [territoryId, 'active'],
    );
    
    if (maps.isNotEmpty) {
      return Attack.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Attack>> getUserAttacks(String userId, {AttackStatus? status}) async {
    final db = await database;
    String whereClause = 'attacker_id = ?';
    List<dynamic> whereArgs = [userId];
    
    if (status != null) {
      whereClause += ' AND status = ?';
      whereArgs.add(status.toString().split('.').last);
    }
    
    final maps = await db.query(
      'attacks',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'started_at DESC',
    );
    
    return maps.map((map) => Attack.fromMap(map)).toList();
  }

  Future<void> updateAttack(Attack attack) async {
    final db = await database;
    await db.update(
      'attacks',
      attack.toMap(),
      where: 'id = ?',
      whereArgs: [attack.id],
    );
  }

  // Game config operations
  Future<GameConfig> getGameConfig() async {
    final db = await database;
    final maps = await db.query(
      'game_config',
      where: 'id = ?',
      whereArgs: ['default'],
    );
    
    if (maps.isNotEmpty) {
      return GameConfig.fromMap(maps.first);
    }
    
    // If no config exists, create default one
    final defaultConfig = GameConfig.defaultConfig();
    await db.insert('game_config', defaultConfig.toMap());
    return defaultConfig;
  }

  Future<void> updateGameConfig(GameConfig config) async {
    final db = await database;
    await db.update(
      'game_config',
      config.toMap(),
      where: 'id = ?',
      whereArgs: [config.id],
    );
  }

  // Utility methods
  Future<int> getTotalUsers() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM users');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTotalTerritories() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM territories');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getOwnedTerritoryCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM territories WHERE owner_id IS NOT NULL');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Territory>> getAttackableTerritories(String userId) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final maps = await db.query(
      'territories',
      where: 'owner_id != ? AND status = ? AND (cooldown_until IS NULL OR cooldown_until < ?)',
      whereArgs: [userId, 'peaceful', now],
      orderBy: 'name ASC',
    );
    
    return maps.map((map) => Territory.fromMap(map)).toList();
  }

  // Transaction methods for complex operations
  Future<void> executeBatch(List<Map<String, dynamic>> operations) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final operation in operations) {
        switch (operation['type']) {
          case 'insert':
            await txn.insert(operation['table'], operation['data']);
            break;
          case 'update':
            await txn.update(
              operation['table'],
              operation['data'],
              where: operation['where'],
              whereArgs: operation['whereArgs'],
            );
            break;
          case 'delete':
            await txn.delete(
              operation['table'],
              where: operation['where'],
              whereArgs: operation['whereArgs'],
            );
            break;
        }
      }
    });
  }

  // Clean up expired cooldowns
  Future<void> cleanupExpiredCooldowns() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.update(
      'territories',
      {
        'status': 'peaceful',
        'cooldown_until': null,
        'updated_at': now,
      },
      where: 'status = ? AND cooldown_until < ?',
      whereArgs: ['cooldown', now],
    );
  }

  // Reset daily attack counts
  Future<void> resetDailyAttackCounts() async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    await db.update(
      'users',
      {
        'attacks_used_today': 0,
        'last_attack_reset': today.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      },
      where: 'last_attack_reset < ?',
      whereArgs: [today.millisecondsSinceEpoch],
    );
  }

  // Close database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // Clear all data (useful for testing)
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('attacks');
      await txn.delete('territories');
      await txn.delete('users');
      await txn.delete('game_config');
    });
    
    // Recreate default data
    await _insertDefaultConfig(db);
    await _insertInitialTerritories(db);
  }
}
