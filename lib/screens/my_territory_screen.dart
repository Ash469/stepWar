import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/territory.dart';
import '../models/user_stats.dart';
import '../widgets/territory_card.dart';
import '../widgets/step_counter_3d.dart';
import '../widgets/animated_progress_bar.dart';
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

  // Mock data
  final UserStats userStats = const UserStats(
    dailySteps: 8547,
    totalSteps: 125430,
    attackPoints: 85,
    shieldPoints: 85,
    territoriesOwned: 1,
    battlesWon: 12,
    battlesLost: 3,
    attacksRemaining: 2,
  );

  final Territory? ownedTerritory = const Territory(
    id: 'paris_001',
    name: 'Paris',
    owner: 'You',
    shieldLevel: 3,
    shieldMax: 5,
    status: TerritoryStatus.peaceful,
  );

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
                    // Header
                    Text(
                      'My Territory',
                      style: Theme.of(context).textTheme.headlineLarge,
                    )
                        .animate()
                        .fadeIn(duration: const Duration(milliseconds: 600))
                        .slideX(begin: -0.3),
                    
                    const SizedBox(height: 24),
                    
                    // Step Counter Section
                    Center(
                      child: Column(
                        children: [
                          StepCounter3D(
                            steps: userStats.dailySteps,
                            label: 'Steps Today',
                            primaryColor: AppTheme.successGold,
                            secondaryColor: AppTheme.primaryDefend,
                            onTap: () {
                              // Mock step increment for demo
                              setState(() {
                                // userStats = userStats.copyWith(dailySteps: userStats.dailySteps + 100);
                              });
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Step conversion info
                          Container(
                            padding: const EdgeInsets.all(16),
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
                                  userStats.attackPointsFromSteps.toString(),
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
                                  userStats.shieldPointsFromSteps.toString(),
                                  AppTheme.primaryDefend,
                                  Icons.shield,
                                ),
                              ],
                            ),
                          )
                              .animate()
                              .fadeIn(delay: const Duration(milliseconds: 300))
                              .slideY(begin: 0.3),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Territory Section
                    if (ownedTerritory != null) ...[
                      Text(
                        'Your Territory',
                        style: Theme.of(context).textTheme.headlineMedium,
                      )
                          .animate()
                          .fadeIn(delay: const Duration(milliseconds: 600))
                          .slideX(begin: -0.3),
                      
                      const SizedBox(height: 16),
                      
                      TerritoryCard(
                        territory: ownedTerritory!,
                        isOwned: true,
                        onReinforce: _reinforceTerritory,
                      )
                          .animate()
                          .fadeIn(delay: const Duration(milliseconds: 800))
                          .slideY(begin: 0.3),
                    ] else ...[
                      // No territory owned
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundSecondary.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.dangerOrange.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.location_off,
                              size: 64,
                              color: AppTheme.dangerOrange,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'You own no territory',
                              style: Theme.of(context).textTheme.headlineSmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Attack one to claim it and start your conquest!',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                // Navigate to World tab
                              },
                              style: AppButtonStyles.attackButton,
                              icon: const Icon(Icons.explore),
                              label: const Text('Explore World'),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: const Duration(milliseconds: 600))
                          .slideY(begin: 0.3),
                    ],
                    
                    const SizedBox(height: 32),
                    
                    // Battle Stats
                    Text(
                      'Battle Statistics',
                      style: Theme.of(context).textTheme.headlineMedium,
                    )
                        .animate()
                        .fadeIn(delay: const Duration(milliseconds: 1000))
                        .slideX(begin: -0.3),
                    
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
                    )
                        .animate()
                        .fadeIn(delay: const Duration(milliseconds: 1200))
                        .slideY(begin: 0.3),
                    
                    const SizedBox(height: 16),
                    
                    _buildBattleStatCard(
                      'Attacks Remaining Today',
                      '${userStats.attacksRemaining} / 3',
                      AppTheme.dangerOrange,
                      Icons.rocket_launch,
                      fullWidth: true,
                    )
                        .animate()
                        .fadeIn(delay: const Duration(milliseconds: 1400))
                        .slideY(begin: 0.3),
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

  void _reinforceTerritory() {
    // Mock reinforcement logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Territory reinforced! +1 Shield'),
        backgroundColor: AppTheme.primaryDefend,
      ),
    );
  }
}

