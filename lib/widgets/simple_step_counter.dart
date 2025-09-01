import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SimpleStepCounter extends StatelessWidget {
  final int steps;
  final VoidCallback? onTap;

  const SimpleStepCounter({
    Key? key,
    required this.steps,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.backgroundSecondary.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.successGold.withOpacity(0.5),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(
              'Steps Today',
              style: AppTextStyles.statusText.copyWith(
                color: AppTheme.textGray,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              steps.toString(),
              style: AppTextStyles.monoNumbers.copyWith(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppTheme.successGold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tap to track workout',
                  style: TextStyle(color: AppTheme.textGray),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppTheme.textGray,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}