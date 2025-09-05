import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../services/firebase_sync_service.dart';
import '../services/step_tracking_service.dart';
import '../models/user.dart';
import 'background_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  bool _isEditingNickname = false;
  bool _showLogoutConfirmation = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _nicknameController.text = authProvider.currentUser?.nickname ?? '';
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    setState(() {
      _showLogoutConfirmation = true;
    });
  }

  Future<void> _confirmLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.signOut();
    setState(() {
      _showLogoutConfirmation = false;
    });
  }

  void _cancelLogout() {
    setState(() {
      _showLogoutConfirmation = false;
    });
  }

  Future<void> _handleUpdateNickname() async {
    final newNickname = _nicknameController.text.trim();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (newNickname.isEmpty || newNickname.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nickname must be at least 3 characters'),
          backgroundColor: AppTheme.primaryAttack,
        ),
      );
      return;
    }

    if (authProvider.currentUser != null) {
      final updatedUser = authProvider.currentUser!.copyWith(
        nickname: newNickname,
      );
      
      final success = await authProvider.updateUserProfile(updatedUser);
      
      if (success) {
        setState(() {
          _isEditingNickname = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nickname updated successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update nickname'),
            backgroundColor: AppTheme.primaryAttack,
          ),
        );
      }
    }
  }

  void _toggleEditNickname() {
    setState(() {
      _isEditingNickname = !_isEditingNickname;
      if (!_isEditingNickname) {
        // Reset to current nickname if cancelling
        _nicknameController.text = Provider.of<AuthProvider>(context, listen: false).currentUser?.nickname ?? '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textWhite,
          ),
        ),
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout,
              color: AppTheme.primaryAttack,
            ),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.currentUser;
          
          if (user == null) {
            // If authenticated but no user profile, show a fallback
            if (authProvider.isAuthenticated) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.person,
                      size: 64,
                      color: AppTheme.successGold,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Setting up your profile...',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppTheme.textWhite,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please wait while we load your information.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textGray,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => authProvider.refreshUserData(),
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              );
            } else {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.successGold),
                ),
              );
            }
          }

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Profile Header
                    Container(
                      padding: const EdgeInsets.all(24),
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
                          // Profile Picture
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.successGold,
                                width: 3,
                              ),
                            ),
                            child: ClipOval(
                              child: user.photoURL != null
                                  ? Image.network(
                                      user.photoURL!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return _buildDefaultAvatar();
                                      },
                                    )
                                  : _buildDefaultAvatar(),
                            ),
                          ).animate().scale(delay: const Duration(milliseconds: 200)),
                          
                          const SizedBox(height: 16),
                          
                          // Nickname with edit functionality
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isEditingNickname) ...[
                                Expanded(
                                  child: TextField(
                                    controller: _nicknameController,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textWhite,
                                    ),
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: AppTheme.successGold.withOpacity(0.5),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: AppTheme.successGold,
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.check,
                                    color: AppTheme.successGreen,
                                  ),
                                  onPressed: _handleUpdateNickname,
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: AppTheme.primaryAttack,
                                  ),
                                  onPressed: _toggleEditNickname,
                                ),
                              ] else ...[
                                Text(
                                  user.nickname,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textWhite,
                                  ),
                                ).animate().fadeIn(delay: const Duration(milliseconds: 300)),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: AppTheme.successGold,
                                    size: 20,
                                  ),
                                  onPressed: _toggleEditNickname,
                                ),
                              ],
                            ],
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Email
                          Text(
                            user.email ?? 'No email',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textGray,
                            ),
                          ).animate().fadeIn(delay: const Duration(milliseconds: 400)),
                        ],
                      ),
                    ).animate().fadeIn(delay: const Duration(milliseconds: 100)).slideY(begin: 0.3),
                    
                    const SizedBox(height: 24),
                    
                    // Real-time Step Tracking Stats
                    _buildRealTimeStepStats(user),
                    
                    const SizedBox(height: 24),
                    
                    // Battle Stats
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Battle Stats',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppTheme.successGold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          _buildStatRow('Shield Points', user.shieldPoints.toString(), Icons.shield, AppTheme.primaryDefend),
                          _buildStatRow('Territories Owned', user.territoriesOwned.toString(), Icons.flag, AppTheme.successGold),
                          _buildStatRow('Attacks Launched', user.totalAttacksLaunched.toString(), Icons.rocket_launch),
                          _buildStatRow('Defenses Won', user.totalDefensesWon.toString(), Icons.security),
                        ],
                      ),
                    ).animate().fadeIn(delay: const Duration(milliseconds: 200)).slideY(begin: 0.3),
                    
                    const SizedBox(height: 24),
                    
                    // Account Section
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppTheme.textWhite,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          _buildAccountRow('Member Since', _formatDate(user.createdAt), Icons.calendar_today),
                          _buildAccountRow('Last Updated', _formatDate(user.updatedAt), Icons.update),
                          _buildAccountRow('User ID', user.id.substring(0, 8) + '...', Icons.fingerprint),
                          
                          const SizedBox(height: 20),
                          
                          // Logout Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _handleLogout,
                              icon: const Icon(Icons.logout),
                              label: const Text(
                                'Sign Out',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: const Duration(milliseconds: 300)).slideY(begin: 0.3),
                  ],
                ),
              ),
              
              // Logout confirmation overlay
              if (_showLogoutConfirmation)
                Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundSecondary,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primaryAttack.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.logout,
                            size: 48,
                            color: AppTheme.primaryAttack,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          const Text(
                            'Sign Out?',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textWhite,
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          const Text(
                            'Are you sure you want to sign out?\nYou can sign back in anytime with Google.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textGray,
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _cancelLogout,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.backgroundDark,
                                    foregroundColor: AppTheme.textWhite,
                                    side: BorderSide(
                                      color: AppTheme.textGray.withOpacity(0.5),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              
                              const SizedBox(width: 12),
                              
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _confirmLogout,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryAttack,
                                    foregroundColor: AppTheme.textWhite,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Sign Out'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().scale(duration: const Duration(milliseconds: 200)),
                  ),
                ).animate().fadeIn(duration: const Duration(milliseconds: 150)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.successGold,
            AppTheme.successGold.withOpacity(0.8),
          ],
        ),
      ),
      child: const Icon(
        Icons.person,
        size: 50,
        color: AppTheme.backgroundDark,
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, [Color? iconColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor ?? AppTheme.textGray,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textGray,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textWhite,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppTheme.textGray,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textGray,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontSize: 16,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Build real-time step stats widget
  Widget _buildRealTimeStepStats(GameUser user) {
    final stepCounter = StepTrackingService();
    final syncService = FirebaseStepSyncService();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.successGreen.withOpacity(0.1),
            AppTheme.successGreen.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.successGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.directions_walk,
                color: AppTheme.successGreen,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Step Tracking',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.successGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Sync status indicator
              StreamBuilder<bool>(
                stream: Stream.periodic(const Duration(seconds: 1), (_) => syncService.isSyncing),
                builder: (context, snapshot) {
                  final isSyncing = snapshot.data ?? false;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSyncing 
                          ? AppTheme.successGreen.withOpacity(0.2)
                          : AppTheme.dangerOrange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSyncing ? AppTheme.successGreen : AppTheme.dangerOrange,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSyncing ? Icons.cloud_done : Icons.cloud_off,
                          color: isSyncing ? AppTheme.successGreen : AppTheme.dangerOrange,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isSyncing ? 'Synced' : 'Offline',
                          style: TextStyle(
                            color: isSyncing ? AppTheme.successGreen : AppTheme.dangerOrange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Real-time step counter
          StreamBuilder<int>(
            stream: stepCounter.stepsStream,
            initialData: stepCounter.dailySteps,
            builder: (context, snapshot) {
              final currentSteps = snapshot.data ?? 0;
              
              return Column(
                children: [
                  // Current Steps (Large Display)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundSecondary.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.successGreen.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Today\'s Steps',
                              style: TextStyle(
                                color: AppTheme.textGray,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentSteps.toString(),
                              style: const TextStyle(
                                color: AppTheme.successGreen,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Distance',
                              style: TextStyle(
                                color: AppTheme.textGray,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${(currentSteps * 0.78 / 1000).toStringAsFixed(2)} km',
                              style: const TextStyle(
                                color: AppTheme.textWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Calories',
                              style: TextStyle(
                                color: AppTheme.textGray,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${(currentSteps * 0.045).toStringAsFixed(0)} kcal',
                              style: const TextStyle(
                                color: AppTheme.textWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Firebase Sync Section - Always show
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDefend.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryDefend.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          syncService.isSyncing ? Icons.cloud_done : Icons.sync,
                          color: syncService.isSyncing ? AppTheme.successGreen : AppTheme.primaryDefend,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Firebase Sync',
                                style: TextStyle(
                                  color: syncService.isSyncing ? AppTheme.successGreen : AppTheme.primaryDefend,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                syncService.isSyncing 
                                    ? 'Syncing today\'s steps: $currentSteps'
                                    : 'Tap to sync your steps to Firebase',
                                style: TextStyle(
                                  color: AppTheme.textGray,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: syncService.isSyncing 
                              ? null // Disable while syncing
                              : () async {
                                  try {
                                    await syncService.forceSyncSteps();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('✅ Steps synced to Firebase successfully!'),
                                          backgroundColor: AppTheme.successGreen,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('❌ Sync failed: ${e.toString()}'),
                                          backgroundColor: AppTheme.dangerOrange,
                                          duration: const Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: syncService.isSyncing 
                                ? AppTheme.textGray
                                : AppTheme.primaryDefend,
                            foregroundColor: AppTheme.textWhite,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            syncService.isSyncing ? 'Syncing...' : 'Sync Now',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Daily Goal Progress (10,000 steps)
          StreamBuilder<int>(
            stream: stepCounter.stepsStream,
            initialData: stepCounter.dailySteps,
            builder: (context, snapshot) {
              final currentSteps = snapshot.data ?? 0;
              const dailyGoal = 10000;
              final progress = (currentSteps / dailyGoal).clamp(0.0, 1.0);
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Daily Goal Progress',
                        style: TextStyle(
                          color: AppTheme.textGray,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: progress >= 1.0 ? AppTheme.successGreen : AppTheme.textWhite,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppTheme.textGray.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1.0 ? AppTheme.successGreen : AppTheme.successGold,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    progress >= 1.0 
                        ? 'Goal achieved! 🎉'
                        : '${dailyGoal - currentSteps} steps to goal',
                    style: TextStyle(
                      color: progress >= 1.0 ? AppTheme.successGreen : AppTheme.textGray,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ).animate().fadeIn(delay: const Duration(milliseconds: 150)).slideY(begin: 0.3);
  }
}
