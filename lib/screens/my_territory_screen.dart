import 'dart:async'; // Import for StreamSubscription
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/territory.dart';
import '../models/user_stats.dart';
import '../models/user.dart';
import '../widgets/territory_card.dart';
import '../providers/game_provider.dart';
import '../services/firebase_game_database.dart';
import '../services/firestore_service.dart';
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

  // User's territories - will be populated from GameProvider
  List<Territory> ownedTerritories = [];

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
  }
  
  /// Load territory data from GameProvider
  void _loadTerritoryData(GameProvider gameProvider) {
    try {
      if (mounted) {
        setState(() {
          // Get user territories from GameProvider
          ownedTerritories = gameProvider.userTerritories;
        });
      }
      
      final currentUser = gameProvider.currentUser;
      if (kDebugMode) {
        print('📊 Territory data loaded: ${ownedTerritories.length} territories');
        print('👤 Current user: ${currentUser?.nickname} (ID: ${currentUser?.id})');
        print('🎯 Expected user ID: ttIkh7ZY8ENdUsmVIH4h0m4DCl82');
        print('🔍 User territories: ${ownedTerritories.map((t) => '${t.name} (owner: ${t.ownerId})').join(', ')}');
        
        // If no territories found, try to debug further
        if (ownedTerritories.isEmpty && currentUser != null) {
          print('⚠️ No territories found for user ${currentUser.id}');
          print('🔍 Checking if user ID matches expected: ${currentUser.id == "ttIkh7ZY8ENdUsmVIH4h0m4DCl82"}');
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to load territory data: $e');
    }
  }

  /// Debug method to manually test territory loading with specific user ID
  Future<void> _debugLoadTerritoriesWithSpecificUserId() async {
    if (kDebugMode) {
      print('🔧 [DEBUG] Manually testing territory loading with user ID: ttIkh7ZY8ENdUsmVIH4h0m4DCl82');
      
      try {
        final gameProvider = Provider.of<GameProvider>(context, listen: false);
        final firebaseDB = FirebaseGameDatabase();
        await firebaseDB.initialize();
        
        // First, check if user exists in Firestore
        final firestoreService = FirestoreService();
        await firestoreService.initialize();
        var user = await firestoreService.getFirestoreUser("ttIkh7ZY8ENdUsmVIH4h0m4DCl82");
        
        if (user == null) {
          print('🔧 [DEBUG] User not found in Firestore');
          print('🔧 [DEBUG] You may need to create this user in Firestore first');
        } else {
          print('🔧 [DEBUG] Found existing user: ${user.nickname} (ID: ${user.id})');
        }
        
        // Now try to load territories
        final territories = await firebaseDB.getUserTerritories("ttIkh7ZY8ENdUsmVIH4h0m4DCl82");
        print('🔧 [DEBUG] Direct query result: ${territories.length} territories');
        for (final territory in territories) {
          print('   • ${territory.name} (owner: ${territory.ownerId})');
        }
        
        if (territories.isNotEmpty) {
          setState(() {
            ownedTerritories = territories;
          });
        }
        
        // Also try to start a game session with this user
        if (user != null) {
          print('🔧 [DEBUG] Starting game session with user...');
          final success = await gameProvider.startGameSession("ttIkh7ZY8ENdUsmVIH4h0m4DCl82");
          print('🔧 [DEBUG] Game session started: $success');
        }
      } catch (e) {
        print('❌ [DEBUG] Error in manual territory loading: $e');
      }
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        // Load territory data when GameProvider updates (only once per build)
        if (mounted) {
          _loadTerritoryData(gameProvider);
        }

        final currentUser = gameProvider.currentUser;
        final userStats = currentUser != null ? UserStats(
          dailySteps: gameProvider.currentStepCount,
          totalSteps: currentUser.totalSteps,
          attackPoints: currentUser.attackPoints,
          shieldPoints: currentUser.shieldPoints,
          territoriesOwned: ownedTerritories.length,
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
                                userStats.territoriesOwned.toString(),
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
                                  ElevatedButton(
                                    onPressed: _debugLoadTerritoriesWithSpecificUserId,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryAttack,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Debug: Load Territories'),
                                  ),
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