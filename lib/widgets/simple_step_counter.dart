import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SimpleStepCounter extends StatelessWidget {
  final int steps;
  final int totalSteps;
  final VoidCallback? onTap;

  const SimpleStepCounter({
    Key? key,
    required this.steps,
    this.totalSteps = 0,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate distance in km (average step length ~0.78m)
    double distanceToday = (steps * 0.78) / 1000; // km
    double totalDistance = (totalSteps * 0.78) / 1000; // km
    double calories = steps * 0.045; // calories burned today

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.backgroundSecondary,
              AppTheme.backgroundSecondary.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.successGold.withOpacity(0.5),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            // Total Stats Section
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryAttack.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Total Progress',
                    style: AppTextStyles.statusText.copyWith(
                      color: AppTheme.primaryAttack,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text(
                            _formatNumber(totalSteps),
                            style: AppTextStyles.monoNumbers.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryAttack,
                            ),
                          ),
                          Text(
                            'Total Steps',
                            style: AppTextStyles.statusText.copyWith(
                              color: AppTheme.textGray,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: AppTheme.textGray.withOpacity(0.3),
                      ),
                      Column(
                        children: [
                          Text(
                            '${totalDistance.toStringAsFixed(1)}km',
                            style: AppTextStyles.monoNumbers.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryAttack,
                            ),
                          ),
                          Text(
                            'Distance',
                            style: AppTextStyles.statusText.copyWith(
                              color: AppTheme.textGray,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Today's Stats Section
            Text(
              'Today\'s Activity',
              style: AppTextStyles.statusText.copyWith(
                color: AppTheme.successGold,
                fontSize: 16,
                fontWeight: FontWeight.bold,
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
            Text(
              'Steps',
              style: AppTextStyles.statusText.copyWith(
                color: AppTheme.textGray,
                fontSize: 14,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Today's detailed stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTodayStatColumn(
                  '${calories.toStringAsFixed(0)}',
                  'Calories',
                  Icons.local_fire_department,
                  AppTheme.dangerOrange,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: AppTheme.textGray.withOpacity(0.3),
                ),
                _buildTodayStatColumn(
                  '${distanceToday.toStringAsFixed(2)}km',
                  'Distance',
                  Icons.route,
                  AppTheme.successGreen,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Action button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.successGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.successGold.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 16,
                    color: AppTheme.successGold,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Tap to start workout',
                    style: TextStyle(
                      color: AppTheme.successGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: AppTheme.successGold,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTodayStatColumn(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.monoNumbers.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.statusText.copyWith(
            color: AppTheme.textGray,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}