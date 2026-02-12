import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/step_history_service.dart';
import '../services/interest_service.dart';
import '../providers/step_provider.dart';
import 'login_screen.dart';
import '../widget/footer.dart';
import 'google_fit_stats_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final InterestService _interestService = InterestService();
  List<String> _allInterests = [];
  bool _isLoadingInterests = true;
  final List<String> _stepRanges = [
    '< 1000',
    '1000 - 3000',
    '3000 - 6000',
    '6000 - 10000',
    '10000 +',
  ];
  UserModel? _user;
  bool _isLoading = true;
  final AuthService _authService = AuthService();

  Map<String, int> _stepHistory = {};
  bool _isChartLoading = true;

  late DateTime _currentWeekStart;
  Map<String, dynamic>? _lifetimeStats;
  bool _isStatsLoading = true;

  @override
  void initState() {
    super.initState();
    _currentWeekStart = _getStartOfWeek(DateTime.now());
    _loadUserProfile();
    _loadStepHistory();
    _loadLifetimeStats();
    _loadAllInterests();
  }

  Future<void> _loadAllInterests() async {
    final interests = await _interestService.fetchInterests();
    if (mounted) {
      setState(() {
        _allInterests = interests;
        _isLoadingInterests = false;
      });
    }
  }

  DateTime _getStartOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  String _formatWeekRange(DateTime startOfWeek) {
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    final formatter = DateFormat('MMM d');
    return '${formatter.format(startOfWeek)} - ${formatter.format(endOfWeek)}';
  }

  bool _isCurrentWeek(DateTime startOfWeek) {
    final now = DateTime.now();
    final startOfCurrentWeek = _getStartOfWeek(now);
    return startOfWeek.year == startOfCurrentWeek.year &&
        startOfWeek.month == startOfCurrentWeek.month &&
        startOfWeek.day == startOfCurrentWeek.day;
  }

  Future<void> _loadUserProfile({bool forceReload = false}) async {
    if (forceReload) {
      setState(() {
        _isLoading = true;
      });
    }
    final prefs = await SharedPreferences.getInstance();
    final userProfileString = prefs.getString('userProfile');
    if (userProfileString != null) {
      final userJson = jsonDecode(userProfileString) as Map<String, dynamic>;

      setState(() {
        _user = UserModel(
          userId: userJson['userId'] ?? '',
          email: userJson['email'],
          username: userJson['username'],
          profileImageUrl: userJson['profileImageUrl'],
          dob: userJson['dob'] != null
              ? DateTime.tryParse(userJson['dob'])
              : null,
          gender: userJson['gender'],
          weight: (userJson['weight'] as num?)?.toDouble(),
          height: (userJson['height'] as num?)?.toDouble(),
          contactNo: userJson['contactNo'],
          stepGoal: (userJson['stepGoal'] as num?)?.toInt(),
          todaysStepCount: (userJson['todaysStepCount'] as num?)?.toInt(),
          interestAreas: (userJson['interestAreas'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
          avgDailySteps: userJson['avgDailySteps'] as String?,
        );

        _isLoading = false;
      });
      if (mounted) {
        final dbSteps = _user?.todaysStepCount ?? 0;
        context.read<StepProvider>().updateDbSteps(dbSteps);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateAndReloadProfile(UserModel updatedUser) async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    setState(() => _isLoading = true);
    try {
      await _authService.updateUserProfile(updatedUser);
      await _loadUserProfile(forceReload: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Error updating profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    }
  }

  Future<void> _loadLifetimeStats() async {
    if (!mounted) return;
    setState(() => _isStatsLoading = true);
    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) throw Exception("User not logged in");

      final stats = await _authService.getLifetimeStats(userId);

      if (mounted) {
        setState(() {
          _lifetimeStats = stats;
          _isStatsLoading = false;
        });
      }
    } catch (e) {
      print("Error loading lifetime stats: $e");
      if (mounted) setState(() => _isStatsLoading = false);
    }
  }

  Future<void> _loadStepHistory({DateTime? weekStartDate}) async {
    if (!mounted) return;
    setState(() => _isChartLoading = true);
    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) throw Exception("User not logged in");
      final List<dynamic> history =
      await _authService.getActivityHistory(userId);
      final Map<String, int> backendMap = {};
      for (var dayData in history) {
        final date = DateTime.tryParse(dayData['date'])?.toLocal();
        if (date != null) {
          final dateString = DateFormat('yyyy-MM-dd').format(date);
          backendMap[dateString] = dayData['stepCount'] ?? 0;
        }
      }
      final stepHistoryService = StepHistoryService();
      await stepHistoryService.loadHistory();

      Map<String, int> processedHistory = {
        'MO': 0,
        'TU': 0,
        'WE': 0,
        'TH': 0,
        'FR': 0,
        'SA': 0,
        'SU': 0
      };
      const dayAbbreviations = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

      final startOfSelectedWeek = weekStartDate ?? _currentWeekStart;

      for (int i = 0; i < 7; i++) {
        final currentDate = startOfSelectedWeek.add(Duration(days: i));
        final dateString = DateFormat('yyyy-MM-dd').format(currentDate);
        final int backendSteps = backendMap[dateString] ?? 0;
        final int localSteps =
            stepHistoryService.getStepsForDate(dateString) ?? 0;
        final int maxSteps =
        (backendSteps > localSteps) ? backendSteps : localSteps;
        String dayAbbreviation = dayAbbreviations[currentDate.weekday - 1];
        processedHistory[dayAbbreviation] = maxSteps;
      }
      if (mounted) {
        setState(() {
          _stepHistory = processedHistory;
          _isChartLoading = false;
        });
      }
    } catch (e) {
      print("Error loading step history: $e");
      if (mounted) setState(() => _isChartLoading = false);
    }
  }

  void _goToPreviousWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
    });
    _loadStepHistory(weekStartDate: _currentWeekStart);
  }

  void _goToNextWeek() {
    if (!_isCurrentWeek(_currentWeekStart)) {
      setState(() {
        _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
      });
      _loadStepHistory(weekStartDate: _currentWeekStart);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.yellow));
    }
    if (_user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Could not load user profile.',
                style: TextStyle(color: Colors.white)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _logout,
              child: const Text('Log Out'),
            ),
          ],
        ),
      );
    }
    final lifetimeBattlesWon =
    (_lifetimeStats?['totalBattlesWon'] ?? 0).toString();
    final lifetimeKnockouts =
    (_lifetimeStats?['totalKnockouts'] ?? 0).toString();
    final lifetimeTotalBattles =
    (_lifetimeStats?['totalBattles'] ?? 0).toString();
    final lifetimeTotalSteps = _lifetimeStats?['totalSteps'] ?? 0;
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: 100.0 +
                        MediaQuery.of(context)
                            .padding
                            .bottom, // Add bottom padding
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 56),
                      _buildProfileHeader(),
                      const SizedBox(height: 24),
                      _buildInfoCard(
                          title: 'About you',
                          child: _buildAboutYouSection(),
                          onEditTap: _showEditAboutYouSheet),
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        title: 'Your Profile',
                        child: _buildYourProfileSection(),
                      ),
                      const SizedBox(height: 24),
                      _buildLifetimeScorecard(
                        battlesWon: lifetimeBattlesWon,
                        knockouts: lifetimeKnockouts,
                        totalBattles: lifetimeTotalBattles,
                        totalSteps: lifetimeTotalSteps,
                      ),
                      const SizedBox(height: 24),
                      _buildStepsChart(),
                      const SizedBox(height: 24),
                      _buildGoogleFitConnect(),
                      const SizedBox(height: 40),
                      const StepWarsFooter(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          top: 16.0,
          right: 16.0,
          child: IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ),
      ],
    );
  }

  void _showEditSheet(
      {required String title,
        required Widget content,
        required VoidCallback onSave}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                content,
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onSave,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.yellow.shade700,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Save',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader() {
    final isPlayGamesUser = _user!.email?.contains('playgames') ?? false;
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey.shade800,
              backgroundImage: _user!.profileImageUrl != null
                  ? NetworkImage(_user!.profileImageUrl!)
                  : null,
              child: _user!.profileImageUrl == null
                  ? const Icon(Icons.person, size: 50, color: Colors.white70)
                  : null,
            ),
            if (isPlayGamesUser)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade900, width: 2),
                  ),
                  child: const Icon(
                    Icons.sports_esports,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _user!.username ?? 'Username',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: IconButton(
                icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
                onPressed: _showEditUsernameSheet,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (isPlayGamesUser)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border:
              Border.all(color: const Color(0xFF4CAF50).withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.sports_esports,
                  size: 14,
                  color: Color(0xFF4CAF50),
                ),
                const SizedBox(width: 6),
                Text(
                  'Play Games Player',
                  style: TextStyle(
                    color: Colors.green[300],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        Text(
          _user!.email ?? 'No email provided',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required Widget child,
    VoidCallback? onEditTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),
              if (onEditTap != null)
                GestureDetector(
                  onTap: onEditTap,
                  child: const Icon(Icons.edit, color: Colors.white, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildAboutYouSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildDetailItem('Gender', _user!.gender ?? 'NA'),
        _buildDetailItem(
            'DOB',
            _user!.dob != null
                ? DateFormat('dd/MM/yyyy').format(_user!.dob!)
                : 'NA'),
        _buildDetailItem(
            'Weight', '${_user!.weight?.toStringAsFixed(1) ?? 'NA'} kg'),
        _buildDetailItem(
            'Height', '${_user!.height?.toStringAsFixed(0) ?? 'NA'} cm'),
      ],
    );
  }

  Widget _buildYourProfileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailItem('Email', _user!.email ?? 'Not provided', isColumn: true),
        const SizedBox(height: 16),
        _buildDetailItem('Contact No.', _user!.contactNo ?? 'Not provided', isColumn: true, onEditTap: _showEditContactSheet),
        const SizedBox(height: 16),
        _buildDetailItem('Daily Step Goal',
          _user?.stepGoal != null && _user!.stepGoal! > 0
              ? NumberFormat.decimalPattern().format(_user!.stepGoal)
              : 'Not Set',
          isColumn: true,
          onEditTap: _showSetGoalSheet,
        ),
        const SizedBox(height: 16),
        _buildDetailItem(
          'Interests',
          (_user?.interestAreas != null && _user!.interestAreas!.isNotEmpty)
              ? _user!.interestAreas!.join(', ')
              : 'Not Set',
          isColumn: true,
          onEditTap: _showEditInterestsSheet,
        ),
        const SizedBox(height: 16),
        _buildDetailItem(
          'Avg Daily Steps',
          _user?.avgDailySteps != null && _user!.avgDailySteps!.isNotEmpty
              ? _user!.avgDailySteps!
              : 'Not Set',
          isColumn: true,
          onEditTap: _showEditAvgDailyStepsSheet,
        ),
      ],
    );
  }


  void _showEditInterestsSheet() {
    final original = List<String>.from(_user?.interestAreas ?? []);
    List<String> selected = List<String>.from(original);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: StatefulBuilder(
              builder: (context, setState) {
                final selectedSet = Set<String>.from(selected);
                final unselected = _allInterests.where((i) => !selectedSet.contains(i)).toList();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Edit Interests', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (selected.isNotEmpty)
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: selected.map((name) => GestureDetector(
                          onTap: () {
                            setState(() { selected.remove(name); });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.yellow.shade700,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.yellow.shade700, width: 1),
                            ),
                            child: Text(name, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                        )).toList(),
                      ),
                    if (selected.isNotEmpty) const SizedBox(height: 18),
                    if (unselected.isNotEmpty)
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: unselected.map((name) => GestureDetector(
                          onTap: () {
                            setState(() { selected.add(name); });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade800, width: 1),
                            ),
                            child: Text(name, style: const TextStyle(color: Colors.white)),
                          ),
                        )).toList(),
                      ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final updatedUser = _user!.copyWith(interestAreas: List<String>.from(selected));
                              await _authService.updateUserProfile(updatedUser);
                              await _loadUserProfile(forceReload: true);
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.yellow.shade700,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black,
                              side: BorderSide(color: Colors.grey.shade400),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    ).then((_) {
      // If closed by cancel or X, restore original (no-op, since not saved)
    });
  }

  void _showEditAvgDailyStepsSheet() {
    final original = _user?.avgDailySteps ?? '';
    String selected = original;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Edit Avg Daily Steps', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _stepRanges.map((range) {
                        final isSelected = selected == range;
                        return GestureDetector(
                          onTap: () {
                            setState(() { selected = range; });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.yellow.shade700 : Colors.black,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? Colors.yellow.shade700 : Colors.grey.shade800, width: 1),
                            ),
                            child: Text(range, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final updatedUser = _user!.copyWith(avgDailySteps: selected);
                              await _authService.updateUserProfile(updatedUser);
                              await _loadUserProfile(forceReload: true);
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.yellow.shade700,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black,
                              side: BorderSide(color: Colors.grey.shade400),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    ).then((_) {
      // If closed by cancel or X, restore original (no-op, since not saved)
    });
  }

  void _showEditUsernameSheet() {
    final usernameController = TextEditingController(text: _user?.username);

    const textStyle = TextStyle(color: Colors.black);
    const labelStyle = TextStyle(color: Colors.black54);

    _showEditSheet(
      title: 'Edit Username',
      content: TextField(
        controller: usernameController,
        style: textStyle,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Username',
          labelStyle: labelStyle,
        ),
        keyboardType: TextInputType.text,
      ),
      onSave: () {
        if (usernameController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Username cannot be empty.'),
                backgroundColor: Colors.red),
          );
          return;
        }
        final updatedUser =
        _user!.copyWith(username: usernameController.text.trim());
        _updateAndReloadProfile(updatedUser);
      },
    );
  }

  void _showEditAboutYouSheet() {
    final weightController =
    TextEditingController(text: _user?.weight?.toStringAsFixed(1));
    final heightController =
    TextEditingController(text: _user?.height?.toStringAsFixed(0));
    DateTime? selectedDob = _user?.dob;
    String? selectedGender = _user?.gender;

    const textStyle = TextStyle(color: Colors.black);
    const labelStyle = TextStyle(color: Colors.black54);

    _showEditSheet(
      title: 'About You',
      content: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Gender', style: labelStyle),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => selectedGender = 'Male'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selectedGender == 'Male'
                              ? Colors.yellow.shade700
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Male',
                            style: TextStyle(
                              color: selectedGender == 'Male'
                                  ? Colors.black
                                  : Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => selectedGender = 'Female'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selectedGender == 'Female'
                              ? Colors.yellow.shade700
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Female',
                            style: TextStyle(
                              color: selectedGender == 'Female'
                                  ? Colors.black
                                  : Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: selectedDob ?? DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      selectedDob = pickedDate;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    labelStyle: labelStyle,
                  ),
                  child: Text(
                    selectedDob != null
                        ? DateFormat('dd/MM/yyyy').format(selectedDob!)
                        : 'Select Date',
                    style: textStyle,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: weightController,
                  style: textStyle,
                  decoration: const InputDecoration(
                    labelText: 'Weight in KG',
                    labelStyle: labelStyle,
                  ),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(
                  controller: heightController,
                  style: textStyle,
                  decoration: const InputDecoration(
                    labelText: 'Height in cm',
                    labelStyle: labelStyle,
                  ),
                  keyboardType: TextInputType.number),
            ],
          );
        },
      ),
      onSave: () {
        final updatedUser = _user!.copyWith(
          gender: selectedGender,
          dob: selectedDob,
          weight: double.tryParse(weightController.text.trim()),
          height: double.tryParse(heightController.text.trim()),
        );
        _updateAndReloadProfile(updatedUser);
      },
    );
  }

  void _showEditContactSheet() {
    final contactController = TextEditingController(text: _user?.contactNo);

    const textStyle = TextStyle(color: Colors.black);
    const labelStyle = TextStyle(color: Colors.black54);

    _showEditSheet(
      title: 'Edit Contact',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: contactController,
            style: textStyle,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Contact No.',
              labelStyle: labelStyle,
            ),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
      onSave: () {
        final updatedUser =
        _user!.copyWith(contactNo: contactController.text.trim());
        _updateAndReloadProfile(updatedUser);
      },
    );
  }

  void _showSetGoalSheet() {
    final goalController =
    TextEditingController(text: _user?.stepGoal?.toString());

    const textStyle = TextStyle(color: Colors.black);
    const labelStyle = TextStyle(color: Colors.black54);

    _showEditSheet(
      title: 'Set Daily Step Goal',
      content: TextField(
        controller: goalController,
        style: textStyle,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Daily Steps',
          labelStyle: labelStyle,
        ),
        keyboardType: TextInputType.number,
      ),
      onSave: () {
        final goalValue = int.tryParse(goalController.text.trim());
        if (goalValue == null || goalValue <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please enter a valid step goal.'),
                backgroundColor: Colors.red),
          );
          return;
        }
        final updatedUser = _user!.copyWith(stepGoal: goalValue);
        _updateAndReloadProfile(updatedUser);
      },
    );
  }

  Widget _buildDetailItem(String label, String value,
      {bool isColumn = false, VoidCallback? onEditTap}) {
    final content = Column(
      crossAxisAlignment:
      isColumn ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
      ],
    );

    if (isColumn) {
      if (onEditTap != null) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: content),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: IconButton(
                icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
                onPressed: onEditTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 20,
              ),
            ),
          ],
        );
      }
      return Align(alignment: Alignment.centerLeft, child: content);
    }

    return content;
  }

  Widget _buildStepsChart() {
    final Map<String, int> stepsData = Map.from(_stepHistory);
    if (_isCurrentWeek(_currentWeekStart) && _user != null) {
      const dayAbbreviations = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
      final todayAbbreviation = dayAbbreviations[DateTime.now().weekday - 1];
      // Use live steps from StepProvider for today's count
      final currentSteps = context.watch<StepProvider>().currentSteps;
      stepsData[todayAbbreviation] = currentSteps;
    }

    final bool hasData = stepsData.values.any((steps) => steps > 0);
    const int maxStepsDefault = 50000;
    final int maxSteps =
    (_user?.stepGoal ?? 0) > 0 ? _user!.stepGoal! : maxStepsDefault;

    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Weekly Steps', style: TextStyle(color: Colors.white)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: _goToPreviousWeek,
              splashRadius: 20,
            ),
            const SizedBox(width: 8),
            Text(_formatWeekRange(_currentWeekStart),
                style: TextStyle(color: Colors.grey.shade400)),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              onPressed:
              _isCurrentWeek(_currentWeekStart) ? null : _goToNextWeek,
              color: _isCurrentWeek(_currentWeekStart)
                  ? Colors.grey.shade700
                  : Colors.white,
              splashRadius: 20,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 150,
          child: _isChartLoading
              ? const Center(
              child: CircularProgressIndicator(color: Colors.yellow))
              : !hasData
              ? Center(
            child: Text(
              "No step data available for this week.",
              style: TextStyle(color: Colors.grey.shade500),
            ),
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: stepsData.entries.map((entry) {
              return _buildBar(
                day: entry.key,
                steps: entry.value,
                maxSteps: maxSteps,
                goalSteps: _user?.stepGoal,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBar({
    required String day,
    required int steps,
    required int maxSteps,
    int? goalSteps,
    double maxBarHeight = 100.0,
  }) {
    final double relativeMax = (maxSteps > 0 ? maxSteps : 10000).toDouble();
    final double barHeight =
    (steps / relativeMax * maxBarHeight).clamp(5.0, maxBarHeight);
    final Color barColor =
    (goalSteps != null && goalSteps > 0 && steps >= goalSteps)
        ? Colors.green.shade400
        : Colors.yellow.shade700;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                NumberFormat.compact().format(steps),
                style: const TextStyle(color: Colors.white, fontSize: 10),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Container(
                height: barHeight,
                width: 20,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
              const SizedBox(height: 8),
              Text(day,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLifetimeScorecard({
    required String battlesWon,
    required String knockouts,
    required String totalBattles,
    required int totalSteps,
  }) {
    int displayedTotalSteps = totalSteps;
    if (_user != null) {
      final int dbTodaysSteps = _user!.todaysStepCount ?? 0;
      final int currentSteps = context.watch<StepProvider>().currentSteps;
      if (currentSteps > dbTodaysSteps) {
        displayedTotalSteps += (currentSteps - dbTodaysSteps);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lifetime Stats',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        ),
        const SizedBox(height: 12),
        // --- Show a loader while stats are loading ---
        _isStatsLoading
            ? const Center(
            child: CircularProgressIndicator(color: Colors.yellow))
            : Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildScorecardItem('assets/images/battle_won.png',
                    battlesWon, 'Battle won'),
                _buildScorecardItem(
                    'assets/images/ko_won.png', knockouts, 'Knockouts'),
                _buildScorecardItem('assets/images/coin_won.png',
                    totalBattles, 'Total Battles'),
              ],
            ),
            const SizedBox(height: 8),
            _buildScorecardItem(
                'assets/images/step_icon.png',
                NumberFormat.decimalPattern().format(totalSteps),
                'Total Lifetime Steps', // Updated label
                isFullWidth: true),
          ],
        ),
      ],
    );
  }

  Widget _buildScorecardItem(String imagePath, String value, String label,
      {bool isFullWidth = false}) {
    Widget content = Container(
      margin: isFullWidth
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 4.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imagePath.isNotEmpty)
            Image.asset(
              imagePath,
              height: 40,
              // Add fallback error builder
              errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.directions_walk,
                  size: 40,
                  color: Colors.white70),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );

    return isFullWidth ? content : Expanded(child: content);
  }

  Widget _buildGoogleFitConnect() {
    return Consumer<StepProvider>(
      builder: (context, stepProvider, child) {
        final isConnected = stepProvider.isGoogleFitEnabled;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: InkWell(
            onTap: () async {
              if (isConnected) {
                // Already connected, navigate to stats
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GoogleFitStatsScreen(),
                  ),
                );
              } else {
                await stepProvider.requestGoogleFitAuthorization();
              }
            },
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? Colors.green.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isConnected ? Icons.check_circle : Icons.health_and_safety,
                    color: isConnected ? Colors.green : Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected
                            ? 'View Google Fit History'
                            : 'Connect Google Fit',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isConnected
                            ? 'View your detailed activity history'
                            : 'Connect Google health data for better tracking of history',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white54,
                  size: 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
