import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/simple_step_counter.dart';
import '../widgets/weekly_step_tracker.dart';
import '../services/step_tracking_service.dart';
import '../services/firebase_sync_service.dart';
import 'exercise_tracking_screen.dart';
import 'dart:math' as math;

class TrackWorkoutScreen extends StatefulWidget {
  const TrackWorkoutScreen({Key? key}) : super(key: key);

  @override
  State<TrackWorkoutScreen> createState() => _TrackWorkoutScreenState();
}

class _TrackWorkoutScreenState extends State<TrackWorkoutScreen>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late Animation<double> _backgroundAnimation;

  final StepTrackingService _stepCounter = StepTrackingService();
  final FirebaseStepSyncService _firebaseSyncService = FirebaseStepSyncService();
  StreamSubscription<int>? _stepSubscription;
  
  int _currentSteps = 0;
  int _totalSteps = 0;
  int _sessionSteps = 0;
  double _calories = 0.0;
  double _distance = 0.0;
  int _activeMinutes = 0;
  
  Map<String, int> _weeklySteps = {
    'mo': 8500,
    'tu': 9200,
    'we': 7800,
    'th': 10500,
    'fr': 9800,
    'sa': 6200,
    'su': 0, // Today
  };

  @override
  void initState() {
    super.initState();
    
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 25),
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
    _initializeStepCounter();
  }

  Future<void> _initializeStepCounter() async {
    try {
      // Get current step count from the already running service
      _currentSteps = _stepCounter.dailySteps;
      _totalSteps = _stepCounter.totalSteps;
      _sessionSteps = _stepCounter.sessionSteps;
      
      // Calculate derived metrics
      _updateMetrics();
      
      // Listen to step updates
      _stepSubscription = _stepCounter.stepsStream.listen((steps) {
        if (mounted) {
          setState(() {
            _currentSteps = steps;
            _sessionSteps = _stepCounter.sessionSteps;
            _updateMetrics();
            
            // Update weekly steps for today
            final today = DateTime.now().weekday;
            final todayKey = _getDayKey(today);
            _weeklySteps[todayKey] = steps;
          });
        }
      });
      
      // Load total steps from Firebase if user is authenticated
      await _loadTotalStepsFromFirebase();
      
      // Update UI with initial values
      if (mounted) {
        setState(() {});
      }
      
    } catch (e) {
      print('❌ Failed to connect to step counter: $e');
    }
  }

  String _getDayKey(int weekday) {
    const days = ['mo', 'tu', 'we', 'th', 'fr', 'sa', 'su'];
    return days[weekday - 1];
  }

  void _updateMetrics() {
    // Calculate calories burned (0.045 cal per step for average adult)
    _calories = _currentSteps * 0.045;
    
    // Calculate distance (average step length: 0.762 meters)
    _distance = (_currentSteps * 0.762) / 1000; // in km
    
    // Estimate active minutes (120 steps per minute average)
    _activeMinutes = _currentSteps ~/ 120;
  }

  Future<void> _loadTotalStepsFromFirebase() async {
    try {
      if (_firebaseSyncService.currentUserId != null) {
        final firebaseData = await _firebaseSyncService.getStepsFromFirebase(_firebaseSyncService.currentUserId!);
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
                  0.3 * math.sin(_backgroundAnimation.value * 0.6),
                  0.3 * math.cos(_backgroundAnimation.value * 0.5),
                ),
                radius: 1.5,
                colors: [
                  const Color(0xFF1A1A1A),
                  const Color(0xFF121212),
                  const Color(0xFF0A0A0A),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Track Workout',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D2D2D),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.primaryAttack.withOpacity(0.8)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.flash_on,
                                color: AppTheme.primaryAttack,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  color: AppTheme.primaryAttack,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: const Duration(milliseconds: 600)).slideX(begin: -0.3),
                    
                    const SizedBox(height: 32),
                    
                    // Main Step Counter
                    Center(
                      child: SimpleStepCounter(
                        steps: _currentSteps,
                        totalSteps: _totalSteps,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ExerciseTrackingScreen(),
                            ),
                          );
                        },
                      ),
                    ).animate().fadeIn(delay: const Duration(milliseconds: 300)).scale(),
                    
                    const SizedBox(height: 32),
                    
                    // Quick Stats
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickStatCard(
                            'Calories',
                            '${_calories.toStringAsFixed(0)}',
                            'kcal',
                            Icons.local_fire_department,
                            AppTheme.primaryAttack,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildQuickStatCard(
                            'Distance',
                            '${_distance.toStringAsFixed(1)}',
                            'km',
                            Icons.straighten,
                            AppTheme.successGreen,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildQuickStatCard(
                            'Active',
                            '$_activeMinutes',
                            'min',
                            Icons.timer,
                            AppTheme.successGold,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: const Duration(milliseconds: 600)).slideY(begin: 0.3),
                    
                    const SizedBox(height: 32),
                    
                    // Weekly Progress
                    Text(
                      'Weekly Progress',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ).animate().fadeIn(delay: const Duration(milliseconds: 800)).slideX(begin: -0.3),
                    
                    const SizedBox(height: 20),
                    
                    Center(
                      child: WeeklyStepTracker(
                        currentSteps: _currentSteps,
                        weeklySteps: _weeklySteps,
                        dailyGoal: 10000,
                      ),
                    ).animate().fadeIn(delay: const Duration(milliseconds: 1000)).scale(),
                    
                    const SizedBox(height: 32),
                    
                    // Workout Actions
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ).animate().fadeIn(delay: const Duration(milliseconds: 1200)).slideX(begin: -0.3),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            'Start Exercise',
                            'Track specific workouts',
                            Icons.play_circle_filled,
                            AppTheme.primaryAttack,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ExerciseTrackingScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildActionCard(
                            'Step History',
                            'View past workouts',
                            Icons.history,
                            AppTheme.primaryDefend,
                            () {
                              _showStepHistory();
                            },
                          ),
                        ),
                      ],
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

  Widget _buildQuickStatCard(String label, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    color: AppTheme.textGray,
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textGray,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppTheme.textGray,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStepHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textGray.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Step History',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<Map<String, int>>(
                  future: _stepCounter.getStepHistory(days: 7),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final history = snapshot.data ?? {};
                    if (history.isEmpty) {
                      return const Center(
                        child: Text(
                          'No step history available',
                          style: TextStyle(color: AppTheme.textGray),
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final entry = history.entries.elementAt(index);
                        final date = entry.key;
                        final steps = entry.value;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D2D2D),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.successGold.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                date,
                                style: const TextStyle(
                                  color: AppTheme.textWhite,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '$steps steps',
                                style: TextStyle(
                                  color: AppTheme.successGold,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
