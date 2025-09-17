import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/step_tracking_service.dart';

class ExerciseTrackingScreen extends StatefulWidget {
  const ExerciseTrackingScreen({Key? key}) : super(key: key);

  @override
  State<ExerciseTrackingScreen> createState() => _ExerciseTrackingScreenState();
}

class _ExerciseTrackingScreenState extends State<ExerciseTrackingScreen> {
  final StepTrackingService _stepTrackingService = StepTrackingService();
  StreamSubscription<int>? _stepSubscription;
  Timer? _timer;

  bool _isTracking = false;
  bool _isPaused = false;
  int _sessionSteps = 0;
  int _initialSteps = 0;
  int _durationInSeconds = 0;

  @override
  void initState() {
    super.initState();
    _setupService();
  }

  Future<void> _setupService() async {
    // Get initial step count from StepTrackingService
    _initialSteps = _stepTrackingService.dailySteps;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stepSubscription?.cancel();
    super.dispose();
  }

  void _startWorkout() {
    setState(() {
      _isTracking = true;
      _isPaused = false;
      _initialSteps = _stepTrackingService.dailySteps;
      _sessionSteps = 0;
      _durationInSeconds = 0;
    });

    // Start timer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isPaused) {
        setState(() {
          _durationInSeconds++;
        });
      }
    });

    // Listen to step updates
    _stepSubscription = _stepTrackingService.stepsStream.listen((totalDailySteps) {
      if (mounted && _isTracking) {
        setState(() {
          _sessionSteps = totalDailySteps - _initialSteps;
        });
      }
    });
  }

  void _pauseWorkout() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _stopWorkout() {
    setState(() {
      _isTracking = false;
      _isPaused = false;
    });
    _timer?.cancel();
    _stepSubscription?.cancel();
    
    // Show workout summary
    _showWorkoutSummary();
  }

  void _resetWorkout() {
    setState(() {
      _isTracking = false;
      _isPaused = false;
      _sessionSteps = 0;
      _durationInSeconds = 0;
    });
    _timer?.cancel();
    _stepSubscription?.cancel();
  }

  void _showWorkoutSummary() {
    final calories = _sessionSteps * 0.045;
    final distance = (_sessionSteps * 0.78) / 1000; // km
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundSecondary,
        title: const Text(
          'Workout Complete! 🏃‍♂️',
          style: TextStyle(color: AppTheme.successGold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryRow('Steps', _sessionSteps.toString()),
            _buildSummaryRow('Duration', _formatDuration(_durationInSeconds)),
            _buildSummaryRow('Calories', '${calories.toStringAsFixed(0)} kcal'),
            _buildSummaryRow('Distance', '${distance.toStringAsFixed(2)} km'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Great!',
              style: TextStyle(color: AppTheme.successGold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textGray)),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textWhite,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final calories = _sessionSteps * 0.045;
    final distance = (_sessionSteps * 0.78) / 1000; // km

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(
          _isTracking ? (_isPaused ? 'Workout Paused' : 'Workout Active') : 'Track Your Workout',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textWhite,
          ),
        ),
        backgroundColor: AppTheme.backgroundSecondary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.successGold),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Workout Status Indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isTracking 
                    ? (_isPaused ? AppTheme.dangerOrange.withOpacity(0.1) : AppTheme.successGreen.withOpacity(0.1))
                    : AppTheme.backgroundSecondary.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isTracking 
                      ? (_isPaused ? AppTheme.dangerOrange : AppTheme.successGreen)
                      : AppTheme.textGray,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isTracking 
                        ? (_isPaused ? Icons.pause_circle : Icons.play_circle)
                        : Icons.fitness_center,
                    color: _isTracking 
                        ? (_isPaused ? AppTheme.dangerOrange : AppTheme.successGreen)
                        : AppTheme.textGray,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isTracking 
                        ? (_isPaused ? 'Workout Paused' : 'Workout in Progress')
                        : 'Ready to Start',
                    style: TextStyle(
                      color: _isTracking 
                          ? (_isPaused ? AppTheme.dangerOrange : AppTheme.successGreen)
                          : AppTheme.textGray,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Main Steps Display
            Column(
              children: [
                Text(
                  'Steps',
                  style: AppTextStyles.statusText.copyWith(
                    fontSize: 18,
                    color: AppTheme.textGray,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_sessionSteps',
                  style: AppTextStyles.monoNumbers.copyWith(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.successGold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Stats Grid
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.backgroundSecondary.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.successGold.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // Duration and Calories Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Time',
                          _formatDuration(_durationInSeconds),
                          Icons.timer,
                          AppTheme.primaryDefend,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Calories',
                          '${calories.toStringAsFixed(0)} kcal',
                          Icons.local_fire_department,
                          AppTheme.dangerOrange,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Distance Row
                  _buildStatCard(
                    'Distance',
                    '${distance.toStringAsFixed(2)} km',
                    Icons.route,
                    AppTheme.successGreen,
                    fullWidth: true,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Control Buttons
            if (!_isTracking) ...[
              // Start Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startWorkout,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text(
                    'Start Workout',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successGreen,
                    foregroundColor: AppTheme.textWhite,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ] else ...[
              // Workout Control Buttons
              Row(
                children: [
                  // Pause/Resume Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pauseWorkout,
                      icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                      label: Text(_isPaused ? 'Resume' : 'Pause'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isPaused ? AppTheme.successGreen : AppTheme.dangerOrange,
                        foregroundColor: AppTheme.textWhite,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Stop Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _stopWorkout,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAttack,
                        foregroundColor: AppTheme.textWhite,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Reset Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _resetWorkout,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset Workout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.backgroundDark,
                    foregroundColor: AppTheme.textGray,
                    side: BorderSide(
                      color: AppTheme.textGray.withOpacity(0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.monoNumbers.copyWith(
              fontSize: fullWidth ? 24 : 20,
              color: color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.statusText.copyWith(
              color: AppTheme.textGray,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
