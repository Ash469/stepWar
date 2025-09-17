import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/weekly_step_tracker.dart';
import '../services/step_tracking_service.dart';
import '../services/firebase_sync_service.dart';
import '../providers/auth_provider.dart';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _pulseController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _pulseAnimation;
  final StepTrackingService _stepCounter = StepTrackingService();
  final FirebaseStepSyncService _firebaseSyncService =
      FirebaseStepSyncService();
  StreamSubscription<int>? _stepSubscription;

  int _currentSteps = 2568;
  int _totalSteps = 25680;

  int _cities = 4;
  int _peace = 3;
  int _attack = 1;
  int _swords = 26;
  int _shields = 40;

  Map<String, int> _weeklySteps = {
    'mo': 8500,
    'tu': 9200,
    'we': 7800,
    'th': 10500,
    'fr': 9800,
    'sa': 6200,
    'su': 2568,
  };

  @override
  void initState() {
    super.initState();
    
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.linear,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _backgroundController.repeat();
    _pulseController.repeat(reverse: true);
    
    _initializeStepCounter();
  }

  Future<void> _initializeStepCounter() async {
    try {
      _currentSteps = _stepCounter.dailySteps;
      await _loadTotalStepsFromFirebase();

      _stepSubscription = _stepCounter.stepsStream.listen((steps) {
        if (mounted) {
          setState(() {
            _currentSteps = steps;
            final today = DateTime.now().weekday;
            final todayKey = _getDayKey(today);
            _weeklySteps[todayKey] = steps;
          });
        }
      });

      if (mounted) setState(() {});
    } catch (e) {
      print('❌ Failed to connect to step counter: $e');
    }
  }

  String _getDayKey(int weekday) {
    const days = ['mo', 'tu', 'we', 'th', 'fr', 'sa', 'su'];
    return days[weekday - 1];
  }

  Future<void> _loadTotalStepsFromFirebase() async {
    try {
      if (_firebaseSyncService.currentUserId != null) {
        final firebaseData = await _firebaseSyncService
            .getStepsFromFirebase(_firebaseSyncService.currentUserId!);
        if (firebaseData != null) {
          _totalSteps = firebaseData['total_steps'] ?? _currentSteps;
        } else {
          _totalSteps = _currentSteps;
        }
      } else {
        _totalSteps = _currentSteps;
      }
    } catch (e) {
      print('❌ Failed to load total steps from Firebase: $e');
      _totalSteps = _currentSteps;
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _pulseController.dispose();
    _stepSubscription?.cancel();
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
                  0.3 * math.sin(_backgroundAnimation.value * 2 * math.pi * 0.1),
                  0.2 * math.cos(_backgroundAnimation.value * 2 * math.pi * 0.15),
                ),
                radius: 1.2,
                colors: [
                  const Color(0xFF1A1A1A),
                  const Color(0xFF121212),
                  const Color(0xFF0A0A0A),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopSection().animate().fadeIn(duration: const Duration(milliseconds: 800)).slideY(begin: -0.3),
                    const SizedBox(height: 32),
                    _buildStepCounterCard().animate().fadeIn(delay: const Duration(milliseconds: 200)).scale(),
                    const SizedBox(height: 32),
                    _buildTerritoryStats().animate().fadeIn(delay: const Duration(milliseconds: 400)).slideX(begin: -0.3),
                    const SizedBox(height: 32),
                    _buildInventorySection().animate().fadeIn(delay: const Duration(milliseconds: 600)).slideX(begin: 0.3),
                    const SizedBox(height: 32),
                    _buildStepsSection().animate().fadeIn(delay: const Duration(milliseconds: 800)).slideY(begin: 0.3),
                    const SizedBox(height: 32),
                    _buildRecommendedSection().animate().fadeIn(delay: const Duration(milliseconds: 1000)).scale(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopSection() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final userName = authProvider.currentUser?.nickname ?? 'Jay';
        final timeOfDay = _getTimeOfDay();

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good $timeOfDay',
                    style: const TextStyle(
                      color: AppTheme.textGray,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppTheme.successGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ready for battle? ⚔️',
                    style: TextStyle(
                      color: AppTheme.primaryAttack.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.successGold,
                          AppTheme.successGold.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.successGold.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.monetization_on,
                          color: AppTheme.backgroundDark,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '1,250',
                          style: TextStyle(
                            color: AppTheme.backgroundDark,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildTerritoryStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Territory',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatCard('0$_cities', 'Cities', Icons.location_city,
                const Color(0xFFFFC107)),
            _buildStatCard('0$_peace', 'Peace', Icons.favorite,
                const Color(0xFF4CAF50)),
            _buildStatCard('0$_attack', 'Attack', Icons.flash_on,
                const Color(0xFFE53935)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2A2A), Color(0xFF1C1C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFB3B3B3),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Inventory',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildInventoryItem(
                  _swords, 'Swords', Icons.security, const Color(0xFFE53935)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInventoryItem(
                  _shields, 'Shields', Icons.shield, const Color(0xFF2196F3)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInventoryItem(
      int count, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2A2A), Color(0xFF1C1C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFB3B3B3),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.7), color.withValues(alpha: 0.3)],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Buy',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Steps',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: WeeklyStepTracker(
            currentSteps: _currentSteps,
            weeklySteps: _weeklySteps,
            dailyGoal: 10000,
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommended',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildRecommendedItem(
                'Conquer',
                'Paris',
                'Anthony',
                Icons.flag,
                const Color(0xFFE53935),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildRecommendedItem(
                'Build',
                'Mumbai',
                'Under attack',
                Icons.construction,
                const Color(0xFFFFC107),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecommendedItem(String action, String location,
      String status, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$action $location selected!'),
            backgroundColor: color,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2A2A2A), Color(0xFF1C1C1C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  action,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              location,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              status,
              style: const TextStyle(
                color: Color(0xFFB3B3B3),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get time of day greeting
  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Morning';
    } else if (hour < 17) {
      return 'Afternoon';
    } else {
      return 'Evening';
    }
  }

  /// Build prominent step counter card
  Widget _buildStepCounterCard() {
    return Center(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          // Navigate to detailed step tracking
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryAttack.withValues(alpha: 0.15),
                AppTheme.primaryDefend.withValues(alpha: 0.15),
                AppTheme.successGold.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.successGold.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.successGold.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_walk,
                    color: AppTheme.successGold,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TODAY\'S STEPS',
                    style: TextStyle(
                      color: AppTheme.successGold,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Text(
                      _currentSteps.toString().replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (Match m) => '${m[1]},')
                      ,
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickStat(
                    'Goal',
                    '10,000',
                    Icons.flag,
                    AppTheme.primaryDefend,
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: AppTheme.textGray.withValues(alpha: 0.3),
                  ),
                  _buildQuickStat(
                    'Calories',
                    '${(_currentSteps * 0.045).toInt()}',
                    Icons.local_fire_department,
                    AppTheme.primaryAttack,
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: AppTheme.textGray.withValues(alpha: 0.3),
                  ),
                  _buildQuickStat(
                    'Distance',
                    '${(_currentSteps * 0.762 / 1000).toStringAsFixed(1)} km',
                    Icons.straighten,
                    AppTheme.successGreen,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build quick stat widget
  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textGray,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
