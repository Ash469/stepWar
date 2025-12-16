import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/step_stats_model.dart';

/// Widget to display weekly and monthly step statistics
class WeeklyMonthlyStatsWidget extends StatelessWidget {
  final WeeklyStepStats? weeklyStats;
  final MonthlyStepStats? monthlyStats;
  final VoidCallback? onRefresh;

  const WeeklyMonthlyStatsWidget({
    Key? key,
    this.weeklyStats,
    this.monthlyStats,
    this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Step Statistics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (onRefresh != null)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: onRefresh,
                  tooltip: 'Refresh stats',
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Weekly Stats Card
          _buildStatsCard(
            title: 'Weekly Stats',
            subtitle: 'Last 7 days',
            totalSteps: weeklyStats?.totalSteps ?? 0,
            averageSteps: weeklyStats?.averageSteps ?? 0,
            dailyData: weeklyStats?.dailyData ?? [],
            color: Colors.blue,
          ),

          const SizedBox(height: 16),

          // Monthly Stats Card
          _buildStatsCard(
            title: 'Monthly Stats',
            subtitle: 'Last 30 days',
            totalSteps: monthlyStats?.totalSteps ?? 0,
            averageSteps: monthlyStats?.averageSteps ?? 0,
            dailyData: monthlyStats?.dailyData ?? [],
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard({
    required String title,
    required String subtitle,
    required int totalSteps,
    required double averageSteps,
    required List<DailyStepData> dailyData,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: color, size: 28),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Total and Average
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  label: 'Total Steps',
                  value: _formatNumber(totalSteps),
                  icon: Icons.directions_walk,
                  color: color,
                ),
                _buildStatItem(
                  label: 'Daily Average',
                  value: _formatNumber(averageSteps.toInt()),
                  icon: Icons.trending_up,
                  color: color,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Simple bar chart
            if (dailyData.isNotEmpty) _buildSimpleBarChart(dailyData, color),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleBarChart(List<DailyStepData> dailyData, Color color) {
    // Find max steps for scaling
    final maxSteps = dailyData.fold<int>(
      0,
      (max, data) => data.steps > max ? data.steps : max,
    );

    if (maxSteps == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No data available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: dailyData.map((data) {
          final heightRatio = maxSteps > 0 ? data.steps / maxSteps : 0.0;
          final barHeight = 100 * heightRatio;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Steps count (show only if significant)
                  if (data.steps > 0)
                    Text(
                      _formatNumberShort(data.steps),
                      style: const TextStyle(
                        fontSize: 8,
                        color: Colors.grey,
                      ),
                    ),
                  const SizedBox(height: 2),
                  // Bar
                  Container(
                    height: barHeight.clamp(2.0, 100.0),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.7),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Date label
                  Text(
                    DateFormat('E').format(data.date).substring(0, 1),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
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

  String _formatNumberShort(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}k';
    }
    return number.toString();
  }
}

/// Compact version for home screen
class CompactStatsWidget extends StatelessWidget {
  final int weeklySteps;
  final int monthlySteps;
  final DateTime? lastSync;
  final VoidCallback? onTap;

  const CompactStatsWidget({
    Key? key,
    required this.weeklySteps,
    required this.monthlySteps,
    this.lastSync,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCompactStat(
                label: 'Week',
                value: _formatNumber(weeklySteps),
                icon: Icons.calendar_view_week,
                color: Colors.blue,
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[300],
              ),
              _buildCompactStat(
                label: 'Month',
                value: _formatNumber(monthlySteps),
                icon: Icons.calendar_month,
                color: Colors.green,
              ),
              if (lastSync != null) ...[
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey[300],
                ),
                Column(
                  children: [
                    const Icon(
                      Icons.sync,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getTimeSinceSync(lastSync!),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
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

  Widget _buildCompactStat({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
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

  String _getTimeSinceSync(DateTime syncTime) {
    final diff = DateTime.now().difference(syncTime);
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
