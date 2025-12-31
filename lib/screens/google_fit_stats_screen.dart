import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/step_provider.dart';
import '../models/step_stats_model.dart';
import '../models/user_model.dart';
import '../const/app_theme.dart';
import '../services/google_fit_service.dart';

/// Professional Google Fit Statistics Screen with interactive charts
class GoogleFitStatsScreen extends StatefulWidget {
  const GoogleFitStatsScreen({Key? key}) : super(key: key);

  @override
  State<GoogleFitStatsScreen> createState() => _GoogleFitStatsScreenState();
}

class _GoogleFitStatsScreenState extends State<GoogleFitStatsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late TabController _tabController;
  int _selectedDayIndex = -1; // For weekly chart interaction
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('userProfile');
      if (userJson != null) {
        setState(() {
          _user = UserModel.fromJson(jsonDecode(userJson));
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final stepProvider = Provider.of<StepProvider>(context, listen: false);

    print('[GoogleFitStats] Loading data...');
    print(
        '[GoogleFitStats] Google Fit enabled: ${stepProvider.isGoogleFitEnabled}');

    if (stepProvider.isGoogleFitEnabled) {
      print('[GoogleFitStats] Syncing all Google Fit data...');
      await stepProvider.syncAllGoogleFitData();

      print(
          '[GoogleFitStats] After sync - Weekly stats: ${stepProvider.weeklyStats}');
      print(
          '[GoogleFitStats] After sync - Monthly stats: ${stepProvider.monthlyStats}');
      print(
          '[GoogleFitStats] After sync - Weekly steps: ${stepProvider.weeklySteps}');
      print(
          '[GoogleFitStats] After sync - Monthly steps: ${stepProvider.monthlySteps}');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Google Fit Stats',
          style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading ? null : _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<StepProvider>(
        builder: (context, stepProvider, child) {
          if (!stepProvider.isGoogleFitEnabled) {
            return _buildNotConnectedView(stepProvider);
          }

          if (_isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            color: AppColors.warning,
            backgroundColor: AppColors.surface,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Today's Steps Hero Card
                  _buildTodayHeroCard(stepProvider),

                  // // Sync Status
                  // _buildSyncStatus(stepProvider),

                  // Tabs for Weekly/Monthly
                  _buildTabSection(stepProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotConnectedView(StepProvider stepProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fitness_center,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Connect Google Fit',
              style: AppTextStyles.headline2.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              'Sync your step data automatically and view detailed statistics',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.onBackground,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                setState(() => _isLoading = true);
                final authorized =
                    await stepProvider.requestGoogleFitAuthorization();
                if (authorized) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Connected successfully!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  await _loadData();
                } else {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          const Text('Failed to connect. Grant permissions.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.link),
              label: Text(_isLoading ? 'Connecting...' : 'Connect Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayHeroCard(StepProvider stepProvider) {
    final todaySteps = stepProvider.currentSteps;
    final goal = _user?.stepGoal ?? 10000; // Use user's goal or default to 10k
    final progress = (todaySteps / goal).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryVariant],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left side - Steps count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TODAY',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white70,
                    letterSpacing: 1.5,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatNumberShort(todaySteps),
                      style: AppTextStyles.headline1.copyWith(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'steps',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progress * 100).toInt()}% of ${_formatNumberShort(goal)}',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Right side - Circular progress
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      progress >= 1.0
                          ? Icons.check_circle
                          : Icons.directions_walk,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MMM d').format(DateTime.now()),
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatus(StepProvider stepProvider) {
    final lastSync = stepProvider.lastGoogleFitSync;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Synced with Google Fit',
                  style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  lastSync != null
                      ? 'Last sync: ${_formatLastSync(lastSync)}'
                      : 'Never synced',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const Icon(Icons.sync, color: AppColors.onBackground, size: 20),
        ],
      ),
    );
  }

  Widget _buildTabSection(StepProvider stepProvider) {
    return Column(
      children: [
        Container(
          // margin: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: AppColors.info,
              borderRadius: BorderRadius.circular(16),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.onBackground,
            labelStyle: AppTextStyles.labelLarge,
            tabs: const [
              Tab(text: 'Weekly'),
              Tab(text: 'Monthly'),
            ],
          ),
        ),
        SizedBox(
          height: 600,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildWeeklyChart(stepProvider),
              _buildMonthlyChart(stepProvider),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyChart(StepProvider stepProvider) {
    final weeklyStats = stepProvider.weeklyStats;

    print('[GoogleFitStats] Building weekly chart...');
    print('[GoogleFitStats] Weekly stats null? ${weeklyStats == null}');
    print(
        '[GoogleFitStats] Daily data count: ${weeklyStats?.dailyData.length ?? 0}');

    if (weeklyStats == null || weeklyStats.dailyData.isEmpty) {
      return _buildNoDataView('No weekly data available yet');
    }

    final maxSteps = weeklyStats.dailyData.fold<int>(
      0,
      (max, data) => data.steps > max ? data.steps : max,
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Row
          Row(
            children: [
              _buildStatBox(
                'Total',
                _formatNumber(weeklyStats.totalSteps),
                AppColors.secondary,
                Icons.directions_walk,
              ),
              const SizedBox(width: 12),
              _buildStatBox(
                'Avg/Day',
                _formatNumber(weeklyStats.averageSteps.toInt()),
                AppColors.warning,
                Icons.trending_up,
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Interactive Bar Chart
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeklyStats.dailyData.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                final isSelected = _selectedDayIndex == index;
                final heightRatio = maxSteps > 0 ? data.steps / maxSteps : 0.0;
                final barHeight = 200 * heightRatio;
                final isToday = data.date.day == DateTime.now().day &&
                    data.date.month == DateTime.now().month;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDayIndex = isSelected ? -1 : index;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Step count (show on selection or if today)
                          if (isSelected || isToday)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isToday
                                    ? AppColors.primary
                                    : AppColors.secondary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _formatNumberShort(data.steps),
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          // Bar
                          Container(
                            height: barHeight.clamp(8.0, 200.0),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isToday
                                    ? [
                                        AppColors.primary,
                                        AppColors.primaryVariant
                                      ]
                                    : isSelected
                                        ? [
                                            AppColors.secondary,
                                            AppColors.secondaryVariant
                                          ]
                                        : [
                                            AppColors.stepInactive,
                                            AppColors.stepInactive
                                                .withOpacity(0.7)
                                          ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                              boxShadow: isSelected || isToday
                                  ? [
                                      BoxShadow(
                                        color: (isToday
                                                ? AppColors.primary
                                                : AppColors.secondary)
                                            .withOpacity(0.5),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Day label
                          Text(
                            DateFormat('E').format(data.date).substring(0, 1),
                            style: AppTextStyles.caption.copyWith(
                              color: isToday || isSelected
                                  ? Colors.white
                                  : AppColors.onBackground,
                              fontWeight: isToday || isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          Text(
                            DateFormat('d').format(data.date),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.onBackground,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart(StepProvider stepProvider) {
    final monthlyStats = stepProvider.monthlyStats;

    print('[GoogleFitStats] Building monthly chart...');
    print('[GoogleFitStats] Monthly stats null? ${monthlyStats == null}');
    print(
        '[GoogleFitStats] Daily data count: ${monthlyStats?.dailyData.length ?? 0}');

    if (monthlyStats == null || monthlyStats.dailyData.isEmpty) {
      return _buildNoDataView('No monthly data available yet');
    }

    final sortedData = List<DailyStepData>.from(monthlyStats.dailyData)
      ..sort((a, b) => b.date.compareTo(a.date));

    final maxSteps = sortedData.fold<int>(
        0, (max, data) => data.steps > max ? data.steps : max);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Row
          Row(
            children: [
              _buildStatBox(
                'Total',
                _formatNumber(monthlyStats.totalSteps),
                AppColors.secondary,
                Icons.directions_walk,
              ),
              const SizedBox(width: 12),
              _buildStatBox(
                'Avg/Day',
                _formatNumber(monthlyStats.averageSteps.toInt()),
                AppColors.warning,
                Icons.trending_up,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Last 30 Days',
            style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          // Scrollable day list
          Expanded(
            child: ListView.builder(
              itemCount: sortedData.length,
              itemBuilder: (context, index) {
                final data = sortedData[index];
                final percentage = maxSteps > 0 ? data.steps / maxSteps : 0.0;
                final isToday = data.date.year == DateTime.now().year &&
                    data.date.month == DateTime.now().month &&
                    data.date.day == DateTime.now().day;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isToday
                        ? AppColors.primary.withOpacity(0.1)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isToday ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Date
                      Container(
                        width: 60,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('MMM').format(data.date),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.onBackground,
                              ),
                            ),
                            Text(
                              DateFormat('d').format(data.date),
                              style: AppTextStyles.titleMedium.copyWith(
                                color:
                                    isToday ? AppColors.primary : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              DateFormat('EEE').format(data.date),
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Progress bar
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_formatNumber(data.steps)} steps',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (isToday)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'TODAY',
                                      style: AppTextStyles.caption.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: percentage,
                                minHeight: 6,
                                backgroundColor: AppColors.stepInactive,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isToday
                                      ? AppColors.primary
                                      : AppColors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTextStyles.titleMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.onBackground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataView([String message = 'No data available']) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart,
            size: 64,
            color: AppColors.onBackground,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onBackground,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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

  String _formatLastSync(DateTime syncTime) {
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
