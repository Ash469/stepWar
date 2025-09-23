import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/weekly_step_tracker.dart';
import '../services/step_tracking_service.dart';
import '../services/firebase_sync_service.dart';
import '../services/firebase_game_database.dart';
import '../providers/auth_provider.dart';
import '../providers/game_provider.dart';
import '../models/territory.dart';
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

  // Territory stats
  late int _territories = 0;
  late int _peace = 0;
  late int _swords = 0;
  late int _shields = 0;

  final Map<String, int> _weeklySteps = {
    'mo': 8500,
    'tu': 9200,
    'we': 7800,
    'th': 10500,
    'fr': 9800,
    'sa': 6200,
    'su': 0, // Will be updated by the stream
  };

  List<Territory> _localTerritories = [];

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

    _initializeGameSession();
  }

  Future<void> _initializeGameSession() async {
    // Wait for the first frame to be rendered to safely access providers
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final gameProvider = Provider.of<GameProvider>(context, listen: false);

      // If auth is ready but game session isn't, start it
      if (authProvider.currentUser != null && gameProvider.currentUser == null) {
        await gameProvider.startGameSession(authProvider.currentUser!.id);
      }

      // Load initial data that doesn't depend on the stream
      _loadTerritoriesFromFirebase();
    });
  }

  Future<void> _loadTerritoriesFromFirebase() async {
    try {
      final gameDB = FirebaseGameDatabase();
      await gameDB.initialize();

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id;

      if (userId != null) {
        final territories = await gameDB.getUserTerritories(userId);
        if (mounted) {
          setState(() {
            _localTerritories = territories;
            _territories = territories.length;
          });
        }
      }
    } catch (e) {
      print('❌ Failed to load territories: $e');
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<int>(
        stream: _stepCounter.stepsStream,
        initialData: _stepCounter.dailySteps,
        builder: (context, snapshot) {
          final currentSteps = snapshot.data ?? _stepCounter.dailySteps;
          final todayKey = _getDayKey(DateTime.now().weekday);
          _weeklySteps[todayKey] = currentSteps;

          return AnimatedBuilder(
            animation: _backgroundAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(
                      0.3 * math.sin(_backgroundAnimation.value * 2 * math.pi * 0.1),
                      0.2 *
                          math.cos(_backgroundAnimation.value * 2 * math.pi * 0.15),
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
                        _buildTopSection()
                            .animate()
                            .fadeIn(duration: const Duration(milliseconds: 800))
                            .slideY(begin: -0.3),
                        const SizedBox(height: 32),
                        _buildStepCounterCard(currentSteps)
                            .animate()
                            .fadeIn(delay: const Duration(milliseconds: 200))
                            .scale(),
                        const SizedBox(height: 32),
                        _buildTerritoryStats()
                            .animate()
                            .fadeIn(delay: const Duration(milliseconds: 400))
                            .slideX(begin: -0.3),
                        const SizedBox(height: 32),
                        _buildInventorySection()
                            .animate()
                            .fadeIn(delay: const Duration(milliseconds: 600))
                            .slideX(begin: 0.3),
                        const SizedBox(height: 32),
                        _buildStepsSection(currentSteps)
                            .animate()
                            .fadeIn(delay: const Duration(milliseconds: 800))
                            .slideY(begin: 0.3),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _getDayKey(int weekday) {
    const days = ['mo', 'tu', 'we', 'th', 'fr', 'sa', 'su'];
    return days[weekday - 1];
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
                      color: AppTheme.primaryAttack.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTerritoryStats() {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        final territories = gameProvider.userTerritories;
        final currentUser = gameProvider.currentUser;

        // Use either GameProvider territories or locally loaded territories
        final territoryCount =
            territories.isNotEmpty ? territories.length : _localTerritories.length;

        // Update state variables
        _territories = territoryCount;
        _peace = currentUser?.shieldPoints ?? 0;
        _swords = currentUser?.attackPoints ?? 0;

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
                _buildStatCard(territoryCount.toString(), 'Territories',
                    Icons.location_city, const Color(0xFFFFC107)),
                _buildStatCard(
                    _peace.toString(), 'Peace', Icons.favorite, const Color(0xFF4CAF50)),
                _buildStatCard(
                    _swords.toString(), 'Attack', Icons.flash_on, const Color(0xFFE53935)),
              ],
            ),
          ],
        );
      },
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
        border: Border.all(color: color.withOpacity(0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
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
                  _swords, 'Attacks', Icons.flash_on, const Color(0xFFE53935)),
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
        border: Border.all(color: color.withOpacity(0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
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
              color: color.withOpacity(0.15),
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
          GestureDetector(
            onTap: () {
              final gameProvider = context.read<GameProvider>();
              if (gameProvider.currentUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please wait, syncing user data...'),
                    backgroundColor: AppTheme.dangerOrange,
                  ),
                );
                return;
              }
              if (label == 'Attacks') {
                _showConvertStepsDialog(context);
              } else if (label == 'Shields') {
                _showConvertStepsDialog(context, isShield: true);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.7),
                    color.withOpacity(0.3)
                  ],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'BUY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showConvertStepsDialog(BuildContext context, {bool isShield = false}) {
    final stepService = StepTrackingService();
    final gameProvider = context.read<GameProvider>();
    final availableSteps = stepService.dailySteps;

    final TextEditingController controller = TextEditingController();
    int stepsToConvert = 0;
    int pointsGained = 0;

    final String title = isShield ? 'Convert to Shield Points' : 'Convert to Attack Points';
    final String conversionRateText = isShield ? '50 steps = 1 shield point' : '10 steps = 1 attack point';
    final int conversionRate = isShield ? 50 : 10;
    final Color accentColor = isShield ? AppTheme.primaryDefend : AppTheme.primaryAttack;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.backgroundSecondary,
              title: Text(title, style: TextStyle(color: accentColor)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available steps today: $availableSteps', style: const TextStyle(color: AppTheme.textGray)),
                  const SizedBox(height: 8),
                  Text(conversionRateText, style: const TextStyle(color: AppTheme.textGray, fontSize: 12)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.textWhite),
                    decoration: InputDecoration(
                      labelText: 'Steps to convert',
                      labelStyle: const TextStyle(color: AppTheme.textGray),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: accentColor),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.textGray),
                      ),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        stepsToConvert = int.tryParse(value) ?? 0;
                        if (stepsToConvert > availableSteps) {
                          stepsToConvert = availableSteps;
                          controller.text = availableSteps.toString();
                          controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
                        }
                        pointsGained = stepsToConvert ~/ conversionRate;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('You will get: $pointsGained ${isShield ? "shield" : "attack"} points', style: TextStyle(color: AppTheme.textWhite)),
                  Text('This will use: ${pointsGained * conversionRate} steps', style: const TextStyle(color: AppTheme.textGray, fontSize: 12)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textGray)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: accentColor),
                  onPressed: (pointsGained > 0) ? () async {
                    final stepsToUse = pointsGained * conversionRate;
                    bool success = false;
                    if (isShield) {
                      success = await gameProvider.convertStepsToShieldPoints(stepsToUse);
                    } else {
                      success = await gameProvider.convertStepsToPoints(stepsToUse);
                    }

                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success
                              ? 'Successfully converted $stepsToUse steps!'
                              : gameProvider.errorMessage ?? 'Conversion failed.'),
                          backgroundColor: success ? AppTheme.successGreen : AppTheme.dangerOrange,
                        ),
                      );
                    }
                  } : null,
                  child: const Text('Convert'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStepsSection(int currentSteps) {
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
            currentSteps: currentSteps,
            weeklySteps: _weeklySteps,
            dailyGoal: 10000,
          ),
        ),
      ],
    );
  }

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

  Widget _buildStepCounterCard(int currentSteps) {
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
                AppTheme.primaryAttack.withOpacity(0.15),
                AppTheme.primaryDefend.withOpacity(0.15),
                AppTheme.successGold.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.successGold.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.successGold.withOpacity(0.1),
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
                  const Icon(
                    Icons.directions_walk,
                    color: AppTheme.successGold,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  const Text(
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
                      currentSteps.toString().replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (Match m) => '${m[1]},'),
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
                    color: AppTheme.textGray.withOpacity(0.3),
                  ),
                  _buildQuickStat(
                    'Calories',
                    '${(currentSteps * 0.045).toInt()}',
                    Icons.local_fire_department,
                    AppTheme.primaryAttack,
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: AppTheme.textGray.withOpacity(0.3),
                  ),
                  _buildQuickStat(
                    'Distance',
                    '${(currentSteps * 0.762 / 1000).toStringAsFixed(1)} km',
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

  Widget _buildQuickStat(
      String label, String value, IconData icon, Color color) {
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

