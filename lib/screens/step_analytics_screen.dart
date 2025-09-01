import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/production_step_counter.dart';
import '../services/step_analytics_service.dart';
import '../services/step_counter_test_utils.dart';
import '../theme/app_theme.dart';

/// Debug screen for monitoring step counter performance and analytics
/// Only available in debug mode for development and tuning
class StepAnalyticsScreen extends StatefulWidget {
  const StepAnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<StepAnalyticsScreen> createState() => _StepAnalyticsScreenState();
}

class _StepAnalyticsScreenState extends State<StepAnalyticsScreen> {
  final ProductionStepCounter _stepCounter = ProductionStepCounter();
  final StepAnalyticsService _analytics = StepAnalyticsService();
  final StepCounterTestUtils _testUtils = StepCounterTestUtils();

  Timer? _refreshTimer;
  AnalyticsReport? _currentReport;
  StepCounterMetrics? _currentMetrics;
  bool _isRunningTests = false;

  @override
  void initState() {
    super.initState();
    _startPeriodicRefresh();
    _refreshData();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _refreshData();
    });
  }

  void _refreshData() {
    if (mounted) {
      setState(() {
        _currentReport = _analytics.getReport();
        _currentMetrics = _stepCounter.getMetrics();
      });
    }
  }

  Future<void> _runAccuracyTests() async {
    if (!kDebugMode) return;
    
    setState(() {
      _isRunningTests = true;
    });

    try {
      final results = await _testUtils.runAccuracyTestSuite();
      final report = _testUtils.generateTestReport(results);
      
      if (mounted) {
        _showTestResults('Accuracy Test Results', report);
      }
    } catch (e) {
      if (mounted) {
        _showError('Test failed: $e');
      }
    } finally {
      setState(() {
        _isRunningTests = false;
      });
    }
  }

  Future<void> _runFalsePositiveTests() async {
    if (!kDebugMode) return;
    
    setState(() {
      _isRunningTests = true;
    });

    try {
      final results = await _testUtils.runFalsePositiveTestSuite();
      final report = _testUtils.generateTestReport(results);
      
      if (mounted) {
        _showTestResults('False Positive Test Results', report);
      }
    } catch (e) {
      if (mounted) {
        _showError('Test failed: $e');
      }
    } finally {
      setState(() {
        _isRunningTests = false;
      });
    }
  }


  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _exportAnalytics() async {
    try {
      final exportData = await _analytics.exportAnalytics();
      await Clipboard.setData(ClipboardData(text: exportData));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Analytics data copied to clipboard')),
        );
      }
    } catch (e) {
      _showError('Export failed: $e');
    }
  }

  Future<void> _clearAnalytics() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Analytics'),
        content: const Text('Are you sure you want to clear all analytics data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _analytics.clearAnalytics();
      _refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(
          child: Text('Analytics screen only available in debug mode'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Step Analytics'),
        backgroundColor: AppTheme.backgroundDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportAnalytics();
                  break;
                case 'clear':
                  _clearAnalytics();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Text('Export Data'),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Text('Clear Data'),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        color: AppTheme.backgroundDark,
        child: _currentReport != null && _currentMetrics != null
            ? _buildAnalyticsContent()
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCurrentStatus(),
          const SizedBox(height: 24),
          _buildSessionMetrics(),
          const SizedBox(height: 24),
          _buildFilterMetrics(),
          const SizedBox(height: 24),
          _buildBoutMetrics(),
          const SizedBox(height: 24),
          _buildTestControls(),
        ],
      ),
    );
  }

  Widget _buildCurrentStatus() {
    final metrics = _currentMetrics!;
    
    return Card(
      color: AppTheme.backgroundSecondary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.successGold,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatusRow('Daily Steps', '${metrics.dailySteps}'),
            _buildStatusRow('Bout Active', metrics.boutActive ? 'Yes' : 'No'),
            _buildStatusRow('Activity', metrics.activityState.toString().split('.').last),
            _buildStatusRow('Consecutive Steps', '${metrics.consecutiveSteps}'),
            if (metrics.algorithmState != null) ...[
              const Divider(color: AppTheme.textGray),
              Text(
                'Algorithm State',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textGray,
                ),
              ),
              const SizedBox(height: 8),
              _buildStatusRow('Buffer Size', '${metrics.algorithmState!.bufferSize}'),
              _buildStatusRow('Recent Peaks', '${metrics.algorithmState!.recentPeaks}'),
              _buildStatusRow('Avg Interval', '${metrics.algorithmState!.averageInterval.toStringAsFixed(0)}ms'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSessionMetrics() {
    final report = _currentReport!;
    final acceptancePercent = (report.acceptanceRate * 100).toStringAsFixed(1);
    
    return Card(
      color: AppTheme.backgroundSecondary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Metrics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.successGold,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatusRow('Session Duration', '${(report.sessionDuration / 60000).toStringAsFixed(1)} min'),
            _buildStatusRow('Total Events', '${report.totalStepEvents}'),
            _buildStatusRow('Accepted Steps', '${report.acceptedSteps}'),
            _buildStatusRow('Rejected Steps', '${report.rejectedSteps}'),
            _buildStatusRow('Acceptance Rate', '$acceptancePercent%'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterMetrics() {
    final report = _currentReport!;
    
    return Card(
      color: AppTheme.backgroundSecondary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Performance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.successGold,
              ),
            ),
            const SizedBox(height: 12),
            ...report.rejectionBreakdown.entries.map(
              (entry) => _buildStatusRow(
                entry.key.replaceAll('_', ' ').toUpperCase(),
                '${entry.value}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoutMetrics() {
    final report = _currentReport!;
    
    return Card(
      color: AppTheme.backgroundSecondary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bout Analytics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.successGold,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatusRow('Total Bouts', '${report.totalBouts}'),
            _buildStatusRow('Avg Duration', '${(report.averageBoutDuration / 60000).toStringAsFixed(1)} min'),
            _buildStatusRow('Avg Steps/Bout', '${report.averageBoutSteps.toStringAsFixed(1)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildTestControls() {
    return Card(
      color: AppTheme.backgroundSecondary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Testing & Validation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.successGold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRunningTests ? null : _runAccuracyTests,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryAttack,
                    ),
                    child: _isRunningTests
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Accuracy Tests'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRunningTests ? null : _runFalsePositiveTests,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryDefend,
                    ),
                    child: _isRunningTests
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('False Positive Tests'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _stepCounter.addSteps(10, source: 'manual_debug');
                    },
                    child: const Text('Add 10 Steps'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final report = _currentReport!;
                      final summary = report.getSummary();
                      _showTestResults('Analytics Summary', summary);
                    },
                    child: const Text('View Summary'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textGray),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textWhite,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showTestResults(String title, String results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundDark,
        title: Text(
          title,
          style: const TextStyle(color: AppTheme.textWhite),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Text(
              results,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppTheme.textGray,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: results));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Results copied to clipboard')),
              );
            },
            child: Text(
              'Copy',
              style: TextStyle(color: AppTheme.successGold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: AppTheme.textGray),
            ),
          ),
        ],
      ),
    );
  }
}

/// Debug floating action button for quick access to analytics
class DebugAnalyticsFAB extends StatelessWidget {
  const DebugAnalyticsFAB({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    return FloatingActionButton(
      mini: true,
      backgroundColor: AppTheme.primaryAttack.withOpacity(0.8),
      child: const Icon(Icons.analytics, size: 20),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const StepAnalyticsScreen(),
          ),
        );
      },
    );
  }
}
