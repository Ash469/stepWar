import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/territory.dart';
import '../models/user_stats.dart';
import '../widgets/territory_card.dart';
import '../providers/game_provider.dart';
import '../services/persistence_service.dart';
import '../services/firebase_game_database.dart';
import '../services/territory_service.dart';
import 'dart:math' as math;

class MyTerritoryScreen extends StatefulWidget {
  const MyTerritoryScreen({Key? key}) : super(key: key);

  @override
  State<MyTerritoryScreen> createState() => _MyTerritoryScreenState();
}

class _MyTerritoryScreenState extends State<MyTerritoryScreen>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late Animation<double> _backgroundAnimation;
  List<Territory> ownedTerritories = [];

  final PersistenceService _persistence = PersistenceService();
  final TerritoryService _territoryService = TerritoryService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    
    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.linear,
    ));
    
    _backgroundController.repeat();
    
    // Load territories on init
    _loadTerritoriesFromStoredAuth();
  }

  /// Load territories using stored authentication data
  Future<void> _loadTerritoriesFromStoredAuth() async {
    try {
      // Get stored auth state
      final authData = _persistence.loadAuthState();
      final userId = authData['userId'] as String?;
      final firebaseUserId = authData['firebaseUserId'] as String?;
      
      if (kDebugMode) {
        print('🔐 [MyTerritory] Loading territories using stored auth:');
        print('   • User ID: $userId');
        print('   • Firebase ID: $firebaseUserId');
      }

      if (userId == null && firebaseUserId == null) {
        setState(() {
          _isLoading = false;
    
        });
        return;
      }

      // Try to load territories using TerritoryService
      final territories = await _territoryService.getMyTerritories();
      
      if (mounted) {
        setState(() {
          ownedTerritories = territories;
          _isLoading = false;
        });
      }

      if (kDebugMode) {
        print('✅ [MyTerritory] Loaded ${territories.length} territories');
        for (final territory in territories) {
          print('   • ${territory.name} (owner: ${territory.ownerId})');
        }
      }

    } catch (e) {
      if (kDebugMode) print('❌ [MyTerritory] Error loading territories: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Load territories directly from Firebase
  Future<void> _loadTerritoriesFromFirebase(String userId) async {
    try {
      if (kDebugMode) print('🔄 [MyTerritory] Loading territories from Firebase for user: $userId');

      // Initialize and use game DB
      final gameDB = FirebaseGameDatabase();
      await gameDB.initialize();
      
      final territories = await gameDB.getUserTerritories(userId);
      
      if (territories.isNotEmpty && mounted) {
        setState(() {
          ownedTerritories = territories;
          _isLoading = false;
        });
        
        if (kDebugMode) {
          print('✅ [MyTerritory] Loaded ${territories.length} territories directly from Firebase');
          for (final territory in territories) {
            print('   • ${territory.name} (owner: ${territory.ownerId})');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ [MyTerritory] Failed to load territories from Firebase: $e');
    }
  }

  /// Load territory data from GameProvider with fallback to Firebase
  void _loadTerritoryData(GameProvider gameProvider) {
    try {
      final currentUser = gameProvider.currentUser;
      if (currentUser == null) {
        if (kDebugMode) print('⚠️ [MyTerritory] No current user found');
        return;
      }

      // Try loading from GameProvider
      final territories = gameProvider.userTerritories;
      
      if (territories.isNotEmpty) {
        if (mounted) {
          setState(() {
            ownedTerritories = territories;
            _isLoading = false;
          });
        }
        return;
      }

      // If no territories in GameProvider, try loading from cache
      if (mounted) {
        _loadTerritoriesFromCache(currentUser.id);
      }
      
    } catch (e) {
      if (kDebugMode) print('❌ [MyTerritory] Failed to load territory data: $e');
    }
  }

  /// Load territories from local cache with Firebase fallback
  Future<void> _loadTerritoriesFromCache(String userId) async {
    try {
      final territories = await _persistence.getCachedTerritories(userId);
      
      if (territories.isNotEmpty) {
        if (mounted) {
          setState(() {
            ownedTerritories = territories;
            _isLoading = false;
          });
        }
        if (kDebugMode) print('✅ [MyTerritory] Loaded ${territories.length} territories from cache');
        return;
      }

      // If cache is empty, try Firebase
      await _loadTerritoriesFromFirebase(userId);
      
    } catch (e) {
      if (kDebugMode) print('❌ [MyTerritory] Failed to load territories from cache: $e');
      // Try Firebase as last resort
      await _loadTerritoriesFromFirebase(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        final currentUser = gameProvider.currentUser;
        final territories = gameProvider.userTerritories;
        
        // Merge territories from both sources
        if (territories.isNotEmpty && territories.length != ownedTerritories.length) {
          setState(() {
            ownedTerritories = territories;
          });
        }

        // Calculate the actual territory count
        final territoryCount = territories.isNotEmpty ? territories.length : ownedTerritories.length;
        
        if (kDebugMode) {
          print('📊 [MyTerritory] Territory count: $territoryCount (GP: ${territories.length}, State: ${ownedTerritories.length})');
        }
        
        final userStats = currentUser != null ? UserStats(
          dailySteps: gameProvider.currentStepCount,
          totalSteps: currentUser.totalSteps,
          attackPoints: currentUser.attackPoints,
          shieldPoints: currentUser.shieldPoints,
          territoriesOwned: territoryCount, // Use calculated count
          battlesWon: currentUser.totalDefensesWon,
          battlesLost: currentUser.totalAttacksLaunched - currentUser.totalTerritoriesCaptured,
          attacksRemaining: 3 - currentUser.attacksUsedToday,
        ) : const UserStats(
          dailySteps: 0,
          totalSteps: 0,
          attackPoints: 0,
          shieldPoints: 0,
          territoriesOwned: 0,
          battlesWon: 0,
          battlesLost: 0,
          attacksRemaining: 0,
        );

        return Scaffold(
          body: AnimatedBuilder(
            animation: _backgroundAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(
                      0.3 * math.sin(_backgroundAnimation.value * 0.8),
                      0.3 * math.cos(_backgroundAnimation.value * 0.7),
                    ),
                    radius: 1.5,
                    colors: [
                      AppTheme.backgroundDark,
                      AppTheme.backgroundSecondary,
                      AppTheme.backgroundDark,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Territory',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ).animate().fadeIn(duration: const Duration(milliseconds: 600)).slideX(begin: -0.3),
                        
                        const SizedBox(height: 24),
                        
                        // Territory Stats Overview
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundSecondary.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.successGold.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatColumn(
                                'Attack Points',
                                userStats.attackPoints.toString(),
                                AppTheme.primaryAttack,
                                Icons.rocket_launch,
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: AppTheme.textGray.withOpacity(0.3),
                              ),
                              _buildStatColumn(
                                'Shield Points',
                                userStats.shieldPoints.toString(),
                                AppTheme.primaryDefend,
                                Icons.shield,
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: AppTheme.textGray.withOpacity(0.3),
                              ),
                              _buildStatColumn(
                                'Territories',
                                '$territoryCount',  // Use calculated count directly
                                AppTheme.successGold,
                                Icons.flag,
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: const Duration(milliseconds: 300)).slideY(begin: 0.3),
                        
                        const SizedBox(height: 32),
                        
                        Text(
                          'Your Territories',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ).animate().fadeIn(delay: const Duration(milliseconds: 600)).slideX(begin: -0.3),
                        
                        const SizedBox(height: 16),
                        
                        // Show message if no territories
                        if (ownedTerritories.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundSecondary.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.textGray.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.flag_outlined,
                                  color: AppTheme.textGray,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Territories Owned',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: AppTheme.textGray,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Start attacking territories to claim them!',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textGray,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (kDebugMode) ...[
                                  const SizedBox(height: 16),
                                ],
                              ],
                            ),
                          ).animate().fadeIn(delay: const Duration(milliseconds: 800)).slideY(begin: 0.3),
                        
                        // Territory Cards
                        ...ownedTerritories.asMap().entries.map((entry) {
                          final index = entry.key;
                          final territory = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TerritoryCard(
                              territory: territory,
                              isOwned: true,
                              onReinforce: () => _reinforceTerritory(territory.name),
                            ).animate().fadeIn(delay: Duration(milliseconds: 800 + (index * 200).round())).slideY(begin: 0.3),
                          );
                        }).toList(),
                        
                        const SizedBox(height: 32),
                        
                        Text(
                          'Battle Statistics',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ).animate().fadeIn(delay: const Duration(milliseconds: 1000)).slideX(begin: -0.3),
                        
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildBattleStatCard(
                                'Battles Won',
                                userStats.battlesWon.toString(),
                                AppTheme.successGreen,
                                Icons.emoji_events,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildBattleStatCard(
                                'Battles Lost',
                                userStats.battlesLost.toString(),
                                AppTheme.primaryAttack,
                                Icons.close,
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: const Duration(milliseconds: 1200)).slideY(begin: 0.3),
                        
                        const SizedBox(height: 16),
                        
                        _buildBattleStatCard(
                          'Attacks Remaining Today',
                          '${userStats.attacksRemaining} / 3',
                          AppTheme.dangerOrange,
                          Icons.rocket_launch,
                          fullWidth: true,
                        ).animate().fadeIn(delay: const Duration(milliseconds: 1400)).slideY(begin: 0.3),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTextStyles.monoNumbers.copyWith(
            fontSize: 18,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.statusText.copyWith(
            color: AppTheme.textGray,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBattleStatCard(
    String label,
    String value,
    Color color,
    IconData icon, {
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.monoNumbers.copyWith(
              fontSize: 20,
              color: color,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.statusText.copyWith(
              color: AppTheme.textGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _reinforceTerritory(String territoryName) async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final currentUser = gameProvider.currentUser;
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please log in to reinforce territories'),
          backgroundColor: AppTheme.dangerOrange,
        ),
      );
      return;
    }

    // Find the territory by name
    final territory = ownedTerritories.firstWhere(
      (t) => t.name == territoryName,
      orElse: () => throw Exception('Territory not found'),
    );

    if (currentUser.shieldPoints <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Not enough shield points to reinforce $territoryName'),
          backgroundColor: AppTheme.dangerOrange,
        ),
      );
      return;
    }

    // Use 1 shield point to reinforce
    final success = await gameProvider.reinforceTerritory(territory.id, 1);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$territoryName reinforced! +1 Shield'),
          backgroundColor: AppTheme.primaryDefend,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reinforce $territoryName'),
          backgroundColor: AppTheme.dangerOrange,
        ),
      );
    }
  }
}