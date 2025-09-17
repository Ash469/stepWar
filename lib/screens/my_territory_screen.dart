import 'dart:async'; // Import for StreamSubscription
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/territory.dart';
import '../models/user_stats.dart';
import '../widgets/territory_card.dart';
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

  // Territory and battle data (will be updated with real data from Firebase)
  UserStats userStats = const UserStats(
    dailySteps: 0,
    totalSteps: 0,
    attackPoints: 150,
    shieldPoints: 120,
    territoriesOwned: 3,
    battlesWon: 12,
    battlesLost: 4,
    attacksRemaining: 2,
  );

  // User's territories
  final List<Territory> ownedTerritories = [
    Territory(
      id: 'paris_001',
      name: 'Paris',
      ownerNickname: 'You',
      currentShield: 4,
      maxShield: 5,
      status: TerritoryStatus.peaceful,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now(),
    ),
    Territory(
      id: 'london_002',
      name: 'London',
      ownerNickname: 'You',
      currentShield: 2,
      maxShield: 5,
      status: TerritoryStatus.underAttack,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now(),
    ),
    Territory(
      id: 'tokyo_003',
      name: 'Tokyo',
      ownerNickname: 'You',
      currentShield: 5,
      maxShield: 5,
      status: TerritoryStatus.peaceful,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now(),
    ),
  ];

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

    // Initialize territory data
    _loadTerritoryData();
  }
  
  /// Load territory data from Firebase
  Future<void> _loadTerritoryData() async {
    try {
      // TODO: Load territory data from Firebase
      // For now using mock data
      if (mounted) {
        setState(() {
          // Territory data already initialized above
        });
      }
      
      if (kDebugMode) print('📊 Territory data loaded');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to load territory data: $e');
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                        ).animate().fadeIn(delay: Duration(milliseconds: 800 + (index * 200))).slideY(begin: 0.3),
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

  void _reinforceTerritory(String territoryName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$territoryName reinforced! +1 Shield'),
        backgroundColor: AppTheme.primaryDefend,
      ),
    );
  }
}