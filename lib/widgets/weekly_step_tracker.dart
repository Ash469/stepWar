import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

class WeeklyStepTracker extends StatelessWidget {
  final int currentSteps;
  final Map<String, int> weeklySteps;
  final int dailyGoal;

  const WeeklyStepTracker({
    Key? key,
    required this.currentSteps,
    this.weeklySteps = const {},
    this.dailyGoal = 10000,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      child: CustomPaint(
        painter: WeeklyStepTrackerPainter(
          currentSteps: currentSteps,
          weeklySteps: weeklySteps,
          dailyGoal: dailyGoal,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryAttack,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_walk,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$currentSteps',
                style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Total steps',
                style: TextStyle(
                  color: AppTheme.textGray,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WeeklyStepTrackerPainter extends CustomPainter {
  final int currentSteps;
  final Map<String, int> weeklySteps;
  final int dailyGoal;

  WeeklyStepTrackerPainter({
    required this.currentSteps,
    required this.weeklySteps,
    required this.dailyGoal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 40;
    
    // Days of the week
    final days = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    final today = DateTime.now().weekday - 1; // Monday = 0
    
    final paintBackground = Paint()
      ..color = AppTheme.textGray.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    
    final paintProgress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    
    final paintToday = Paint()
      ..color = AppTheme.primaryAttack
      ..style = PaintingStyle.fill;
    
    final paintComplete = Paint()
      ..color = AppTheme.successGold
      ..style = PaintingStyle.fill;
    
    final paintActive = Paint()
      ..color = AppTheme.successGreen
      ..style = PaintingStyle.fill;
    
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i < 7; i++) {
      final angle = (i * 2 * math.pi / 7) - math.pi / 2;
      final startAngle = angle - (2 * math.pi / 7) / 2 + 0.1;
      const sweepAngle = (2 * math.pi / 7) - 0.2;
      
      // Background arc
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paintBackground,
      );
      
      // Get steps for this day
      final dayKey = days[i].toLowerCase();
      final steps = weeklySteps[dayKey] ?? (i == today ? currentSteps : 0);
      final progress = (steps / dailyGoal).clamp(0.0, 1.0);
      
      if (steps > 0) {
        // Progress color based on completion
        if (progress >= 1.0) {
          paintProgress.color = AppTheme.successGold;
        } else if (i == today) {
          paintProgress.color = AppTheme.primaryAttack;
        } else {
          paintProgress.color = AppTheme.successGreen;
        }
        
        // Progress arc
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle * progress,
          false,
          paintProgress,
        );
      }
      
      // Day indicator dot
      final dotX = center.dx + (radius + 20) * math.cos(angle);
      final dotY = center.dy + (radius + 20) * math.sin(angle);
      final dotCenter = Offset(dotX, dotY);
      
      Paint dotPaint;
      if (i == today) {
        dotPaint = paintToday;
      } else if (progress >= 1.0) {
        dotPaint = paintComplete;
      } else if (steps > 0) {
        dotPaint = paintActive;
      } else {
        dotPaint = Paint()
          ..color = AppTheme.textGray.withOpacity(0.3)
          ..style = PaintingStyle.fill;
      }
      
      canvas.drawCircle(dotCenter, 12, dotPaint);
      
      // Day label
      textPainter.text = TextSpan(
        text: days[i],
        style: TextStyle(
          color: i == today ? AppTheme.textWhite : AppTheme.textGray,
          fontSize: 10,
          fontWeight: i == today ? FontWeight.bold : FontWeight.normal,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(dotX - textPainter.width / 2, dotY - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(WeeklyStepTrackerPainter oldDelegate) {
    return currentSteps != oldDelegate.currentSteps ||
           weeklySteps != oldDelegate.weeklySteps ||
           dailyGoal != oldDelegate.dailyGoal;
  }
}
