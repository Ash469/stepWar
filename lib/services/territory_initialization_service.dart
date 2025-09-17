import 'package:flutter/foundation.dart';
import '../models/game_config.dart';
import 'firebase_game_database.dart';

class TerritoryInitializationService {
  static final TerritoryInitializationService _instance = TerritoryInitializationService._internal();
  factory TerritoryInitializationService() => _instance;
  TerritoryInitializationService._internal();

  final FirebaseGameDatabase _gameDB = FirebaseGameDatabase();

  // ==========================================================================
  // TERRITORY DATA
  // ==========================================================================

  /// List of real-world territories for the MVP
  static const List<TerritoryData> _territoryData = [
    // Major World Cities (Tier 1 - High Strategic Value)
    TerritoryData('New York', 'USA', 40.7128, -74.0060, 8, 15),
    TerritoryData('London', 'UK', 51.5074, -0.1278, 7, 14),
    TerritoryData('Tokyo', 'Japan', 35.6762, 139.6503, 8, 16),
    TerritoryData('Paris', 'France', 48.8566, 2.3522, 7, 13),
    TerritoryData('Singapore', 'Singapore', 1.3521, 103.8198, 6, 12),
    TerritoryData('Sydney', 'Australia', -33.8688, 151.2093, 6, 11),
    TerritoryData('Dubai', 'UAE', 25.2048, 55.2708, 6, 12),
    TerritoryData('Hong Kong', 'China', 22.3193, 114.1694, 7, 13),
    TerritoryData('Seoul', 'South Korea', 37.5665, 126.9780, 6, 12),
    TerritoryData('Los Angeles', 'USA', 34.0522, -118.2437, 7, 13),
    
    // Major Regional Centers (Tier 2 - Medium Strategic Value)
    TerritoryData('Berlin', 'Germany', 52.5200, 13.4050, 5, 10),
    TerritoryData('Amsterdam', 'Netherlands', 52.3676, 4.9041, 5, 9),
    TerritoryData('Toronto', 'Canada', 43.6532, -79.3832, 5, 10),
    TerritoryData('Mumbai', 'India', 19.0760, 72.8777, 6, 11),
    TerritoryData('Bangkok', 'Thailand', 13.7563, 100.5018, 5, 10),
    TerritoryData('Istanbul', 'Turkey', 41.0082, 28.9784, 5, 10),
    TerritoryData('Cairo', 'Egypt', 30.0444, 31.2357, 5, 9),
    TerritoryData('São Paulo', 'Brazil', -23.5558, -46.6396, 6, 11),
    TerritoryData('Mexico City', 'Mexico', 19.4326, -99.1332, 5, 10),
    TerritoryData('Moscow', 'Russia', 55.7558, 37.6173, 6, 11),
    TerritoryData('Rome', 'Italy', 41.9028, 12.4964, 5, 9),
    TerritoryData('Madrid', 'Spain', 40.4168, -3.7038, 5, 9),
    TerritoryData('Vienna', 'Austria', 48.2082, 16.3738, 4, 8),
    TerritoryData('Stockholm', 'Sweden', 59.3293, 18.0686, 4, 8),
    TerritoryData('Copenhagen', 'Denmark', 55.6761, 12.5683, 4, 8),
    
    // Regional Cities (Tier 3 - Standard Strategic Value)
    TerritoryData('Barcelona', 'Spain', 41.3851, 2.1734, 4, 8),
    TerritoryData('Milan', 'Italy', 45.4642, 9.1900, 4, 8),
    TerritoryData('Brussels', 'Belgium', 50.8503, 4.3517, 4, 7),
    TerritoryData('Zurich', 'Switzerland', 47.3769, 8.5417, 4, 8),
    TerritoryData('Oslo', 'Norway', 59.9139, 10.7522, 3, 7),
    TerritoryData('Helsinki', 'Finland', 60.1699, 24.9384, 3, 7),
    TerritoryData('Dublin', 'Ireland', 53.3498, -6.2603, 4, 7),
    TerritoryData('Edinburgh', 'Scotland', 55.9533, -3.1883, 3, 7),
    TerritoryData('Warsaw', 'Poland', 52.2297, 21.0122, 4, 8),
    TerritoryData('Prague', 'Czech Republic', 50.0755, 14.4378, 4, 7),
    TerritoryData('Budapest', 'Hungary', 47.4979, 19.0402, 4, 7),
    TerritoryData('Athens', 'Greece', 37.9838, 23.7275, 4, 7),
    TerritoryData('Lisbon', 'Portugal', 38.7223, -9.1393, 4, 7),
    TerritoryData('Vancouver', 'Canada', 49.2827, -123.1207, 4, 8),
    TerritoryData('Montreal', 'Canada', 45.5017, -73.5673, 4, 8),
    TerritoryData('Chicago', 'USA', 41.8781, -87.6298, 5, 9),
    TerritoryData('Miami', 'USA', 25.7617, -80.1918, 4, 8),
    TerritoryData('Seattle', 'USA', 47.6062, -122.3321, 4, 8),
    TerritoryData('San Francisco', 'USA', 37.7749, -122.4194, 5, 9),
    TerritoryData('Boston', 'USA', 42.3601, -71.0589, 4, 8),
    
    // Asia-Pacific Regional Centers
    TerritoryData('Melbourne', 'Australia', -37.8136, 144.9631, 4, 8),
    TerritoryData('Brisbane', 'Australia', -27.4698, 153.0251, 3, 7),
    TerritoryData('Perth', 'Australia', -31.9505, 115.8605, 3, 7),
    TerritoryData('Auckland', 'New Zealand', -36.8485, 174.7633, 3, 7),
    TerritoryData('Wellington', 'New Zealand', -41.2865, 174.7762, 3, 6),
    TerritoryData('Manila', 'Philippines', 14.5995, 120.9842, 5, 9),
    TerritoryData('Jakarta', 'Indonesia', -6.2088, 106.8456, 5, 9),
    TerritoryData('Kuala Lumpur', 'Malaysia', 3.1390, 101.6869, 4, 8),
    TerritoryData('Ho Chi Minh City', 'Vietnam', 10.8231, 106.6297, 4, 8),
    TerritoryData('Taipei', 'Taiwan', 25.0330, 121.5654, 4, 8),
    TerritoryData('Osaka', 'Japan', 34.6937, 135.5023, 5, 9),
    TerritoryData('Busan', 'South Korea', 35.1796, 129.0756, 4, 7),
    
    // Middle East & Africa
    TerritoryData('Tel Aviv', 'Israel', 32.0853, 34.7818, 4, 8),
    TerritoryData('Doha', 'Qatar', 25.2854, 51.5310, 4, 8),
    TerritoryData('Abu Dhabi', 'UAE', 24.2539, 54.3773, 4, 8),
    TerritoryData('Riyadh', 'Saudi Arabia', 24.7136, 46.6753, 4, 8),
    TerritoryData('Kuwait City', 'Kuwait', 29.3759, 47.9774, 3, 7),
    TerritoryData('Amman', 'Jordan', 31.9539, 35.9106, 3, 6),
    TerritoryData('Beirut', 'Lebanon', 33.8938, 35.5018, 3, 6),
    TerritoryData('Casablanca', 'Morocco', 33.5731, -7.5898, 4, 7),
    TerritoryData('Lagos', 'Nigeria', 6.5244, 3.3792, 5, 9),
    TerritoryData('Cape Town', 'South Africa', -33.9249, 18.4241, 4, 7),
    TerritoryData('Johannesburg', 'South Africa', -26.2041, 28.0473, 4, 8),
    TerritoryData('Nairobi', 'Kenya', -1.2921, 36.8219, 4, 7),
    
    // South America
    TerritoryData('Buenos Aires', 'Argentina', -34.6037, -58.3816, 5, 9),
    TerritoryData('Lima', 'Peru', -12.0464, -77.0428, 4, 7),
    TerritoryData('Bogotá', 'Colombia', 4.7110, -74.0721, 4, 7),
    TerritoryData('Santiago', 'Chile', -33.4489, -70.6693, 4, 7),
    TerritoryData('Caracas', 'Venezuela', 10.4806, -66.9036, 3, 6),
    TerritoryData('Montevideo', 'Uruguay', -34.9011, -56.1645, 3, 6),
    TerritoryData('Quito', 'Ecuador', -0.1807, -78.4678, 3, 6),
    TerritoryData('La Paz', 'Bolivia', -16.5000, -68.1193, 3, 6),
    
    // Additional North American Cities
    TerritoryData('Atlanta', 'USA', 33.7490, -84.3880, 4, 7),
    TerritoryData('Dallas', 'USA', 32.7767, -96.7970, 4, 7),
    TerritoryData('Houston', 'USA', 29.7604, -95.3698, 4, 7),
    TerritoryData('Philadelphia', 'USA', 39.9526, -75.1652, 4, 7),
    TerritoryData('Phoenix', 'USA', 33.4484, -112.0740, 3, 6),
    TerritoryData('Denver', 'USA', 39.7392, -104.9903, 3, 6),
    TerritoryData('San Diego', 'USA', 32.7157, -117.1611, 4, 7),
    TerritoryData('Las Vegas', 'USA', 36.1699, -115.1398, 3, 6),
    
    // Additional European Cities
    TerritoryData('Munich', 'Germany', 48.1351, 11.5820, 4, 7),
    TerritoryData('Frankfurt', 'Germany', 50.1109, 8.6821, 4, 7),
    TerritoryData('Lyon', 'France', 45.7640, 4.8357, 3, 6),
    TerritoryData('Marseille', 'France', 43.2965, 5.3698, 3, 6),
    TerritoryData('Naples', 'Italy', 40.8518, 14.2681, 3, 6),
    TerritoryData('Florence', 'Italy', 43.7696, 11.2558, 3, 6),
    TerritoryData('Venice', 'Italy', 45.4408, 12.3155, 3, 6),
    TerritoryData('Nice', 'France', 43.7102, 7.2620, 3, 6),
    TerritoryData('Geneva', 'Switzerland', 46.2044, 6.1432, 4, 7),
    TerritoryData('Salzburg', 'Austria', 47.8095, 13.0550, 3, 5),
    
    // Additional Asian Cities
    TerritoryData('Shanghai', 'China', 31.2304, 121.4737, 6, 11),
    TerritoryData('Beijing', 'China', 39.9042, 116.4074, 6, 11),
    TerritoryData('Guangzhou', 'China', 23.1291, 113.2644, 5, 9),
    TerritoryData('Shenzhen', 'China', 22.5431, 114.0579, 5, 9),
    TerritoryData('Macau', 'China', 22.1987, 113.5439, 3, 6),
    TerritoryData('New Delhi', 'India', 28.6139, 77.2090, 6, 11),
    TerritoryData('Bangalore', 'India', 12.9716, 77.5946, 5, 9),
    TerritoryData('Chennai', 'India', 13.0827, 80.2707, 4, 8),
    TerritoryData('Kolkata', 'India', 22.5726, 88.3639, 4, 8),
    TerritoryData('Hyderabad', 'India', 17.3850, 78.4867, 4, 8),
    
    // Island Nations & Unique Locations
    TerritoryData('Reykjavik', 'Iceland', 64.1466, -21.9426, 2, 5),
    TerritoryData('Honolulu', 'USA', 21.3099, -157.8581, 3, 6),
    TerritoryData('Anchorage', 'USA', 61.2181, -149.9003, 2, 4),
    TerritoryData('Malta', 'Malta', 35.9375, 14.3754, 2, 5),
    TerritoryData('Luxembourg', 'Luxembourg', 49.6116, 6.1319, 3, 6),
    TerritoryData('Monaco', 'Monaco', 43.7384, 7.4246, 2, 4),
    TerritoryData('Gibraltar', 'Gibraltar', 36.1408, -5.3536, 2, 4),
    TerritoryData('Bermuda', 'Bermuda', 32.2949, -64.7815, 2, 4),
    TerritoryData('Maldives', 'Maldives', 3.2028, 73.2207, 2, 4),
    TerritoryData('Bahrain', 'Bahrain', 26.0667, 50.5577, 3, 6),
  ];

  // ==========================================================================
  // INITIALIZATION METHODS
  // ==========================================================================

  /// Initialize all territories in the database
  Future<bool> initializeAllTerritories() async {
    try {
      if (kDebugMode) print('🌍 [TerritoryInit] Starting territory initialization...');
      
      // Check if territories already exist
      final existingTerritories = await _gameDB.getAllTerritories();
      if (existingTerritories.isNotEmpty) {
        if (kDebugMode) print('⚠️ [TerritoryInit] Territories already exist (${existingTerritories.length}). Skipping initialization.');
        return true;
      }
      
      // Get game configuration
      final config = await _gameDB.getGameConfig() ?? GameConfig.defaultConfig();
      
      if (kDebugMode) {
        print('🎯 [TerritoryInit] Using game config:');
        print('   • Max territories: ${config.maxTerritories}');
        print('   • Starting shield range: ${config.newUserStartingShieldMin}-${config.newUserStartingShieldMax}');
      }
      
      // Take only the number of territories allowed by configuration
      final territoriesToCreate = _territoryData.take(config.maxTerritories).toList();
      
      if (kDebugMode) print('🏗️ [TerritoryInit] Creating ${territoriesToCreate.length} territories...');
      
      int successCount = 0;
      int failureCount = 0;
      
      for (final territoryData in territoriesToCreate) {
        final success = await _createTerritory(territoryData, config);
        if (success) {
          successCount++;
        } else {
          failureCount++;
        }
        
        // Add small delay to avoid overwhelming Firebase
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      if (kDebugMode) {
        print('✅ [TerritoryInit] Territory initialization complete!');
        print('   • Successfully created: $successCount territories');
        print('   • Failed to create: $failureCount territories');
        print('   • Total territories in system: $successCount');
      }
      
      return failureCount == 0;
      
    } catch (e) {
      if (kDebugMode) print('❌ [TerritoryInit] Error during initialization: $e');
      return false;
    }
  }

  /// Create a single territory from territory data
  Future<bool> _createTerritory(TerritoryData data, GameConfig config) async {
    try {
      // Calculate initial shield based on territory tier and config
      final baseShield = _calculateInitialShield(data, config);
      final maxShield = _calculateMaxShield(data, config);
      
      final territory = await _gameDB.createTerritory(
        name: '${data.name}, ${data.country}',
        initialShield: baseShield,
        maxShield: maxShield,
        latitude: data.latitude,
        longitude: data.longitude,
      );
      
      if (territory != null && kDebugMode) {
        print('🏰 [TerritoryInit] Created: ${territory.name} (Shield: ${territory.currentShield}/${territory.maxShield})');
      }
      
      return territory != null;
    } catch (e) {
      if (kDebugMode) print('❌ [TerritoryInit] Failed to create ${data.name}: $e');
      return false;
    }
  }

  /// Calculate initial shield level for a territory
  int _calculateInitialShield(TerritoryData data, GameConfig config) {
    // Use the territory's suggested starting shield, bounded by config
    return data.startingShield.clamp(
      config.newUserStartingShieldMin,
      config.newUserStartingShieldMax + 2, // Allow slightly higher for special territories
    );
  }

  /// Calculate maximum shield level for a territory
  int _calculateMaxShield(TerritoryData data, GameConfig config) {
    // Max shield is typically 2-3x the starting shield
    final calculated = (data.maxShield * 1.5).round();
    return calculated.clamp(
      config.newUserStartingShieldMax,
      20, // Reasonable upper limit
    );
  }

  // ==========================================================================
  // UTILITY METHODS
  // ==========================================================================

  /// Get statistics about territory initialization
  Future<Map<String, dynamic>> getInitializationStats() async {
    try {
      final territories = await _gameDB.getAllTerritories();
      final config = await _gameDB.getGameConfig() ?? GameConfig.defaultConfig();
      
      return {
        'territories_created': territories.length,
        'max_territories_allowed': config.maxTerritories,
        'initialization_complete': territories.length >= config.maxTerritories,
        'unowned_territories': territories.where((t) => !t.isOwned).length,
        'owned_territories': territories.where((t) => t.isOwned).length,
        'average_shield_level': territories.isNotEmpty 
            ? territories.fold<int>(0, (sum, t) => sum + t.currentShield) / territories.length
            : 0,
        'total_shield_capacity': territories.fold<int>(0, (sum, t) => sum + t.maxShield),
      };
    } catch (e) {
      if (kDebugMode) print('❌ [TerritoryInit] Error getting initialization stats: $e');
      return {'error': e.toString()};
    }
  }

  /// Reset all territories (dangerous operation - for testing only)
  Future<bool> resetAllTerritories() async {
    if (!kDebugMode) {
      if (kDebugMode) print('❌ [TerritoryInit] Territory reset only allowed in debug mode');
      return false;
    }
    
    try {
      if (kDebugMode) print('⚠️ [TerritoryInit] DANGER: Resetting all territories...');
      
      // This would require implementing a delete method in FirebaseGameDatabase
      // For now, just log the intention
      if (kDebugMode) print('🔄 [TerritoryInit] Territory reset not implemented - would clear all territory data');
      
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ [TerritoryInit] Error resetting territories: $e');
      return false;
    }
  }

  /// Check if initialization is needed
  Future<bool> isInitializationNeeded() async {
    try {
      final territories = await _gameDB.getAllTerritories();
      final config = await _gameDB.getGameConfig() ?? GameConfig.defaultConfig();
      
      return territories.length < config.maxTerritories;
    } catch (e) {
      if (kDebugMode) print('❌ [TerritoryInit] Error checking if initialization needed: $e');
      return true; // Assume initialization is needed if we can't check
    }
  }
}

// ==========================================================================
// DATA CLASSES
// ==========================================================================

class TerritoryData {
  final String name;
  final String country;
  final double latitude;
  final double longitude;
  final int startingShield;
  final int maxShield;

  const TerritoryData(
    this.name,
    this.country,
    this.latitude,
    this.longitude,
    this.startingShield,
    this.maxShield,
  );

  @override
  String toString() => '$name, $country ($startingShield/$maxShield shields)';
}
