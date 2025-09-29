import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/game_service.dart';
import '../services/step_counting.dart';
import '../widget/footer.dart';
import 'battle_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserModel? _user;
  bool _isLoading = true;
  final AuthService _authService = AuthService();
  final HealthService _healthService = HealthService();
  StreamSubscription? _stepSubscription;
  Timer? _debounce;
  int _latestSteps = 0;

  // New variables for game creation
  final GameService _gameService = GameService();
  bool _isCreatingGame = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initHealthService();
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    _debounce?.cancel();
    _healthService.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userProfileString = prefs.getString('userProfile');
    if (userProfileString != null) {
      final userJson = jsonDecode(userProfileString) as Map<String, dynamic>;
      DateTime? parsedDob;
      final dobData = userJson['dob'];
      if (dobData != null && dobData is String) {
        parsedDob = DateTime.tryParse(dobData);
      }
      if (mounted) {
        setState(() {
          _user = UserModel(
            userId: userJson['userId'] ?? '',
            email: userJson['email'],
            username: userJson['username'],
            profileImageUrl: userJson['profileImageUrl'],
            dob: parsedDob,
            gender: userJson['gender'],
            weight: (userJson['weight'] as num?)?.toDouble(),
            height: (userJson['height'] as num?)?.toDouble(),
            contactNo: userJson['contactNo'],
            stepGoal: (userJson['stepGoal'] as num?)?.toInt(),
            todaysStepCount: (userJson['todaysStepCount'] as num?)?.toInt(),
          );
          _latestSteps = _user?.todaysStepCount ?? 0;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _initHealthService() {
    _healthService.initialize();
    _stepSubscription =
        _healthService.stepStream.listen(_onStepCount, onError: (error) {
      print("Error from HealthService stream: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    });
  }

  void _onStepCount(String stepsStr) {
    final steps = int.tryParse(stepsStr);
    if (steps == null) return;

    if (mounted) {
      setState(() {
        _user = _user?.copyWith(todaysStepCount: steps);
        _latestSteps = steps;
      });
    }

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(seconds: 15), _saveLatestSteps);
  }

  Future<void> _saveLatestSteps() async {
    if (_user != null) {
      print("Saving step count: $_latestSteps");
      final updatedUser = _user!.copyWith(todaysStepCount: _latestSteps);
      try {
        await _authService.updateUserProfile(updatedUser);
        print("Successfully saved steps.");
      } catch (e) {
        print("Error saving step count: $e");
      }
    }
  }

  // --- MODIFIED METHOD ---
  Future<void> _startOnlineBattle() async {
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load user profile.')),
      );
      return;
    }

    setState(() => _isCreatingGame = true);

    try {
      final gameId = await _gameService.createOnlineGame(_user!);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BattleScreen(gameId: gameId, user: _user!),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start game: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingGame = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.yellow));
    }
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildStepCounterCard(),
            const SizedBox(height: 24),
            _buildSectionTitle("---------- Today's Scorecard ----------"),
            const SizedBox(height: 16),
            _buildScorecard(),
            const SizedBox(height: 24),
            _buildSectionTitle("---------- Start A Battle ----------"),
            const SizedBox(height: 16),
            _buildBattleOptions(),
            const SizedBox(height: 16),
            _buildGameRules(),
            const SizedBox(height: 24),
            _buildSectionTitle("---------- Rewards ----------"),
            const SizedBox(height: 16),
            _buildRewardsCard(),
            const SizedBox(height: 24),
            _buildSectionTitle("---------- Mystery Box ----------"),
            const SizedBox(height: 16),
            _buildMysteryBoxes(),
            const SizedBox(height: 16),
            const StepWarsFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCounterCard() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16.0),
        gradient: LinearGradient(
          colors: [Colors.yellow.shade800, Colors.yellow.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.yellow.shade800.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Steps",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _user?.todaysStepCount?.toString() ?? '0',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.directions_walk, size: 60, color: Colors.black),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome Back,',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 18),
            ),
            Text(
              _user?.username ?? 'User',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color.fromARGB(213, 249, 188, 35),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              Image(
                  image: AssetImage('assets/images/coin_icon.png'),
                  width: 24,
                  height: 24),
              SizedBox(width: 8),
              Text(
                '150',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildScorecard() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildScorecardItem('assets/images/battle_won.png', '04', 'Battle won'),
        _buildScorecardItem('assets/images/ko_won.png', '03', 'Knockouts'),
        _buildScorecardItem('assets/images/coin_won.png', '5685', 'Coins won'),
      ],
    );
  }

  Widget _buildScorecardItem(String imagePath, String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imagePath.isNotEmpty) Image.asset(imagePath, height: 40),
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
      ),
    );
  }

  Widget _buildBattleOptions() {
    return Row(
      children: [
        _buildBattleOption(
          'Online Battle',
          'assets/images/battle_online.png',
          onTap: _isCreatingGame ? null : _startOnlineBattle,
          isLoading: _isCreatingGame,
        ),
        const SizedBox(width: 16),
        _buildBattleOption(
          'Battle a Friend',
          'assets/images/battle_friend.png',
          onTap: () {
            // Placeholder for friend battle
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming Soon!')));
          },
        ),
      ],
    );
  }

  Widget _buildBattleOption(String title, String imagePath,
      {VoidCallback? onTap, bool isLoading = false}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade800),
          ),
          child: Column(
            children: [
              Image.asset(imagePath, height: 80),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDD85D)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(title,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameRules() {
    Widget buildRule(String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '•  ',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Game Rules",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        buildRule(
            "The player with the most steps at the end of 60 min wins the battle."),
        buildRule(
            "If a player leads by 3000 steps, they gets KO immediately."),
        buildRule(
            "All steps are converted to coins, which can be used to upgrade your kingdom."),
      ],
    );
  }

  Widget _buildRewardsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_city,
                  color: Colors.orange.shade400, size: 30),
              const SizedBox(width: 12),
              const Text("Mumbai",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Mumbai is the financial capital and the most populous city proper of India with an estimated...",
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMysteryBoxes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildMysteryBox('assets/images/bronze_box.png', '10:25:10', true),
        _buildMysteryBox('assets/images/silver_box.png', '1000', false),
        _buildMysteryBox('assets/images/gold_box.png', '2000', false),
      ],
    );
  }

  Widget _buildMysteryBox(String imagePath, String label, bool isTimer) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: Image.asset(
                imagePath,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isTimer ? Colors.transparent : Colors.yellow.shade800,
                borderRadius: BorderRadius.circular(20),
                border:
                    isTimer ? Border.all(color: Colors.grey.shade700) : null,
              ),
              child: isTimer
                  ? Text(
                      label,
                      style: const TextStyle(color: Colors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/coin_icon.png',
                          width: 20,
                          height: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          label,
                          style: const TextStyle(color: Colors.white),
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

extension UserModelCopyWith on UserModel {
  UserModel copyWith({
    String? username,
    String? email,
    String? profileImageUrl,
    DateTime? dob,
    String? gender,
    double? weight,
    double? height,
    String? contactNo,
    int? stepGoal,
    int? todaysStepCount,
  }) {
    return UserModel(
      userId: userId,
      email: email ?? this.email,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      contactNo: contactNo ?? this.contactNo,
      stepGoal: stepGoal ?? this.stepGoal,
      todaysStepCount: todaysStepCount ?? this.todaysStepCount,
    );
  }
}
