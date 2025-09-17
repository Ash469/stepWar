import 'dart:async';
import 'package:flutter/material.dart';
import '../services/production_step_counter.dart';
import '../theme/app_theme.dart';

/// Real-time step counter widget that shows immediate step updates
class RealTimeStepCounter extends StatefulWidget {
  const RealTimeStepCounter({Key? key}) : super(key: key);

  @override
  State<RealTimeStepCounter> createState() => _RealTimeStepCounterState();
}

class _RealTimeStepCounterState extends State<RealTimeStepCounter>
    with TickerProviderStateMixin {
  final ProductionStepCounter _stepCounter = ProductionStepCounter();
  late StreamSubscription<int> _stepsSubscription;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  int _currentSteps = 0;
  int _lastSteps = 0;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.elasticOut,
    ));

    // Initialize step counter
    _initializeStepCounter();
  }

  Future<void> _initializeStepCounter() async {
    await _stepCounter.initialize();
    await _stepCounter.startTracking();
    
    // Listen to step updates
    _stepsSubscription = _stepCounter.stepsStream.listen((steps) {
      setState(() {
        _lastSteps = _currentSteps;
        _currentSteps = steps;
        
        // Animate when steps increase
        if (steps > _lastSteps) {
          _pulseController.reset();
          _pulseController.forward();
        }
      });
    });
    
    // Get initial step count
    setState(() {
      _currentSteps = _stepCounter.dailySteps;
    });
  }

  @override
  void dispose() {
    _stepsSubscription.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.backgroundSecondary,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Step Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.successGold.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.directions_walk,
                size: 32,
                color: AppTheme.successGold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Step Count with Animation
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Text(
                    '$_currentSteps',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successGold,
                      fontFamily: 'RobotoMono',
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 8),
            
            // Label
            const Text(
              'Daily Steps',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textGray,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Step Increment Indicator
            if (_currentSteps > _lastSteps)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.successGreen.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.trending_up,
                      size: 16,
                      color: AppTheme.successGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+${_currentSteps - _lastSteps}',
                      style: const TextStyle(
                        color: AppTheme.successGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
