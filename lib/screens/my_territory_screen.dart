import 'dart:async'; // Import for StreamSubscription
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/territory.dart';
import '../models/user_stats.dart';
import '../widgets/territory_card.dart';
import '../widgets/simple_step_counter.dart'; 
import 'exercise_tracking_screen.dart';
import '../services/step_tracking_service.dart'; // Import the step tracking service
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

  final StepTrackingService _stepCounter = StepTrackingService();
  StreamSubscription<int>? _stepSubscription;
  int _currentSteps = 0;
  int _totalSteps = 0; // Will be updated with live data

  // Mock data for other parts of the UI (will be updated with real data)
  UserStats userStats = const UserStats(
    dailySteps: 0,
    totalSteps: 0,
    attackPoints: 0,
    shieldPoints: 0,
    territoriesOwned: 1,
    battlesWon: 0,
    battlesLost: 0,
    attacksRemaining: 3,
  );

  final Territory? ownedTerritory = Territory(
    id: 'paris_001',
    name: 'Paris',
    ownerNickname: 'You',
    currentShield: 3,
    maxShield: 5,
    status: TerritoryStatus.peaceful,
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
    updatedAt: DateTime.now(),
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

    // Initialize step counter asynchronously
    _initializeStepCounter();
  }
  
  /// Initialize step counter and start tracking
  Future<void> _initializeStepCounter() async {
    try {
      // Don't reinitialize - service is already initialized in main.dart
      // Just connect to the existing service and listen to its stream
      
      // Get current step count from the already running service
      _currentSteps = _stepCounter.dailySteps;
      _totalSteps = _currentSteps; // For now, total steps equals today's steps since we're using simple tracking
      
      _stepSubscription = _stepCounter.stepsStream.listen((steps) {
        if (mounted) {
          setState(() {
            _currentSteps = steps;
            _totalSteps = steps; // Simple: total = today's steps
            
            // Update userStats with live data
            userStats = userStats.copyWith(
              dailySteps: steps,
              totalSteps: _totalSteps,
            );
          });
        }
      });
      
      // Update UI with initial values
      if (mounted) {
        setState(() {
          userStats = userStats.copyWith(
            dailySteps: _currentSteps,
            totalSteps: _totalSteps,
          );
        });
      }
      
    } catch (e) {
      print('❌ Failed to connect to step counter: $e');
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _stepSubscription?.cancel(); // Cancel subscription
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate attack and shield points based on live steps
    int attackPoints = _currentSteps ~/ 100;
    int shieldPoints = _currentSteps ~/ 100;

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
                    
                    Center(
                      child: Column(
                        children: [
                          SimpleStepCounter(
                            steps: _currentSteps, // Use live step data
                            totalSteps: _totalSteps, // Pass total steps
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ExerciseTrackingScreen(),
                                ),
                              );
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
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
                                  attackPoints.toString(), // Use calculated points
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
                                  shieldPoints.toString(), // Use calculated points
                                  AppTheme.primaryDefend,
                                  Icons.shield,
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: const Duration(milliseconds: 300)).slideY(begin: 0.3),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    if (ownedTerritory != null) ...[
                      Text(
                        'Your Territory',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ).animate().fadeIn(delay: const Duration(milliseconds: 600)).slideX(begin: -0.3),
                      
                      const SizedBox(height: 16),
                      
                      TerritoryCard(
                        territory: ownedTerritory!,
                        isOwned: true,
                        onReinforce: _reinforceTerritory,
                      ).animate().fadeIn(delay: const Duration(milliseconds: 800)).slideY(begin: 0.3),
                    ] else ...[
                      // No territory owned section...
                    ],
                    
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

  void _reinforceTerritory() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Territory reinforced! +1 Shield'),
        backgroundColor: AppTheme.primaryDefend,
      ),
    );
  }
}