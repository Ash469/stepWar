import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/workmanager_background_service.dart';

class BackgroundSettingsScreen extends StatefulWidget {
  const BackgroundSettingsScreen({Key? key}) : super(key: key);

  @override
  State<BackgroundSettingsScreen> createState() => _BackgroundSettingsScreenState();
}

class _BackgroundSettingsScreenState extends State<BackgroundSettingsScreen> {
  final BackgroundStepService _backgroundService = BackgroundStepService();
  
  bool _backgroundServiceEnabled = false;
  bool _backgroundServiceRunning = false;
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBackgroundServiceStatus();
  }

  Future<void> _loadBackgroundServiceStatus() async {
    setState(() {
      _loading = true;
    });

    try {
      _backgroundServiceRunning = await _backgroundService.isBackgroundServiceRunning();
      _backgroundServiceEnabled = _backgroundServiceRunning;
    } catch (e) {
      _errorMessage = 'Failed to load background service status: $e';
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _toggleBackgroundService(bool enabled) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      if (enabled) {
        final success = await _backgroundService.startBackgroundCounting();
        if (success) {
          _backgroundServiceEnabled = true;
          _backgroundServiceRunning = true;
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Background step counting enabled'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        } else {
          throw Exception('Failed to start background service. Please check permissions.');
        }
      } else {
        await _backgroundService.stopBackgroundCounting();
        _backgroundServiceEnabled = false;
        _backgroundServiceRunning = false;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Background step counting disabled'),
            backgroundColor: AppTheme.primaryAttack,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _backgroundServiceEnabled = !enabled; // Revert state
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppTheme.primaryAttack,
        ),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _syncBackgroundSteps() async {
    setState(() {
      _loading = true;
    });

    try {
      await _backgroundService.syncWithMainCounter();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Background steps synced successfully'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: AppTheme.primaryAttack,
        ),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _showBackgroundSteps() async {
    try {
      final backgroundSteps = await _backgroundService.getBackgroundSteps();
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.backgroundSecondary,
            title: const Text(
              'Background Steps',
              style: TextStyle(color: AppTheme.textWhite),
            ),
            content: Text(
              'Background service has counted $backgroundSteps steps today.',
              style: const TextStyle(color: AppTheme.textGray),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(color: AppTheme.successGold),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get background steps: $e'),
          backgroundColor: AppTheme.primaryAttack,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text(
          'Background Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textWhite,
          ),
        ),
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppTheme.successGold,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.successGold),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
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
                        color: AppTheme.successGold.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.directions_run,
                          size: 48,
                          color: AppTheme.successGold,
                        ).animate().scale(),
                        
                        const SizedBox(height: 16),
                        
                        Text(
                          'Background Step Counting',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.textWhite,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
                        
                        const SizedBox(height: 8),
                        
                        Text(
                          'Keep counting steps even when the app is closed',
                          style: TextStyle(
                            color: AppTheme.textGray,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: const Duration(milliseconds: 300)),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: 0.3),
                  
                  const SizedBox(height: 24),
                  
                  // Main Settings
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundSecondary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryAttack.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Enable/Disable Toggle
                        Row(
                          children: [
                            Icon(
                              Icons.settings,
                              color: AppTheme.successGold,
                              size: 24,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Background Counting',
                                    style: const TextStyle(
                                      color: AppTheme.textWhite,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _backgroundServiceRunning
                                        ? 'Service is running'
                                        : 'Service is stopped',
                                    style: TextStyle(
                                      color: _backgroundServiceRunning
                                          ? AppTheme.successGreen
                                          : AppTheme.textGray,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _backgroundServiceEnabled,
                              onChanged: _toggleBackgroundService,
                              activeColor: AppTheme.successGold,
                              activeTrackColor: AppTheme.successGold.withOpacity(0.3),
                              inactiveThumbColor: AppTheme.textGray,
                              inactiveTrackColor: AppTheme.backgroundDark,
                            ),
                          ],
                        ),
                        
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryAttack.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.primaryAttack.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppTheme.primaryAttack,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: AppTheme.primaryAttack,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ).animate().fadeIn(delay: const Duration(milliseconds: 100)).slideY(begin: 0.3),
                  
                  const SizedBox(height: 16),
                  
                  // Action Buttons
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundSecondary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.backgroundSecondary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Actions',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.textWhite,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Sync Button
                        ElevatedButton.icon(
                          onPressed: _syncBackgroundSteps,
                          icon: const Icon(Icons.sync),
                          label: const Text('Sync Background Steps'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successGold,
                            foregroundColor: AppTheme.backgroundDark,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // View Background Steps Button
                        ElevatedButton.icon(
                          onPressed: _showBackgroundSteps,
                          icon: const Icon(Icons.visibility),
                          label: const Text('View Background Steps'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryAttack,
                            foregroundColor: AppTheme.textWhite,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: const Duration(milliseconds: 200)).slideY(begin: 0.3),
                  
                  const SizedBox(height: 16),
                  
                  // Information
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundSecondary.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryAttack.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppTheme.primaryAttack,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'How it Works',
                              style: TextStyle(
                                color: AppTheme.primaryAttack,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• Background service runs continuously\n'
                          '• Steps are counted even when app is closed\n'
                          '• Battery optimization may affect performance\n'
                          '• Sync periodically to ensure accuracy\n'
                          '• Requires additional permissions',
                          style: TextStyle(
                            color: AppTheme.textGray,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: const Duration(milliseconds: 300)).slideY(begin: 0.3),
                ],
              ),
            ),
    );
  }
}
