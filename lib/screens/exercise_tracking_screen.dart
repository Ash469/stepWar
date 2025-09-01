import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../theme/app_theme.dart';
import '../services/production_step_counter.dart';
import '../services/game_manager_service.dart';

class ExerciseTrackingScreen extends StatefulWidget {
  const ExerciseTrackingScreen({Key? key}) : super(key: key);

  @override
  State<ExerciseTrackingScreen> createState() => _ExerciseTrackingScreenState();
}

class _ExerciseTrackingScreenState extends State<ExerciseTrackingScreen> {
  final ProductionStepCounter _stepCounter = ProductionStepCounter();
  StreamSubscription<int>? _stepSubscription;
  Timer? _timer;

  bool _isTracking = false;
  int _sessionSteps = 0;
  int _initialSteps = 0;
  int _durationInSeconds = 0;

  @override
  void initState() {
    super.initState();
    _setupService();
  }

  Future<void> _setupService() async {
    // The ProductionStepCounter should already be initialized and running from main.dart
    // We just need to get the current step count to track session steps
    _initialSteps = _stepCounter.dailySteps;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stepSubscription?.cancel();
    // Don't stop the ProductionStepCounter - it should keep running
    super.dispose();
  }

  void _toggleTracking() async {
    setState(() {
      _isTracking = !_isTracking;
    });

    if (_isTracking) {
      // Reset session stats - get current step count as starting point
      _initialSteps = _stepCounter.dailySteps;
      _sessionSteps = 0;
      _durationInSeconds = 0;

      // Timer for workout duration
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _durationInSeconds++;
          });
        }
      });

      // Listen to the ProductionStepCounter's step stream
      _stepSubscription =
          _stepCounter.stepsStream.listen((totalDailySteps) {
        if (mounted) {
          setState(() {
            _sessionSteps = totalDailySteps - _initialSteps;
          });
        }
      });
    } else {
      // Stop only the session tracking, not the main step counter
      _timer?.cancel();
      _stepSubscription?.cancel();
    }
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
  
  /// Reset user's step count to fix step tracking issues (debug only)
  Future<void> _resetStepCount() async {
    try {
      await GameManagerService().resetCurrentUserStepCount();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Step count synchronized with pedometer'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to reset step count: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Add testing points for immediate gameplay (debug only)
  Future<void> _addTestingPoints() async {
    try {
      await GameManagerService().giveCurrentUserTestingPoints(
        attackPoints: 50,
        shieldPoints: 50,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎮 Added 50 attack points and 50 shield points for testing'),
            backgroundColor: Colors.purple,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to add testing points: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Your Workout'),
        backgroundColor: AppTheme.backgroundSecondary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Session Steps',
                style: AppTextStyles.statusText.copyWith(
                  fontSize: 24,
                  color: AppTheme.textGray,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$_sessionSteps',
                style: AppTextStyles.monoNumbers.copyWith(
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.successGold,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard(
                      'Duration', _formatDuration(_durationInSeconds)),
                  _buildStatCard('Calories Burned',
                      '${(_sessionSteps * 0.04).toStringAsFixed(1)}'),
                ],
              ),
              const SizedBox(height: 64),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _toggleTracking,
                  icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                  label: Text(_isTracking ? 'End Workout' : 'Start Workout'),
                  style: _isTracking
                      ? AppButtonStyles.attackButton
                      : AppButtonStyles.successButton,
                ),
              ),
              
              // Debug buttons (only show in debug mode)
              if (kDebugMode) ...[  
                const SizedBox(height: 32),
                Text(
                  'Debug Tools',
                  style: AppTextStyles.statusText.copyWith(
                    fontSize: 18,
                    color: AppTheme.textGray,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _resetStepCount,
                        child: Text('Fix Steps'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _addTestingPoints,
                        child: Text('Add Points'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.statusText.copyWith(
            fontSize: 18,
            color: AppTheme.textGray,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTextStyles.monoNumbers.copyWith(
            fontSize: 32,
            color: AppTheme.textWhite,
          ),
        ),
      ],
    );
  }
}
