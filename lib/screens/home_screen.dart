import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/game_service.dart';
import '../services/step_counting.dart';
import '../widget/footer.dart';
import 'battle_screen.dart';
import 'waiting_for_friend_screen.dart';
import 'bot_selection_screen.dart';
import '../widget/game_rules.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final HealthService _healthService = HealthService();
  final GameService _gameService = GameService();

  UserModel? _user;
  bool _isLoading = true;
  StreamSubscription? _stepSubscription;
  Timer? _debounce;
  bool _isCreatingBotGame = false;
  bool _isHandlingFriendGame = false;
  int _stepsToShow = 0;
  int dailyStepOffset = -1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    _debounce?.cancel();
    _healthService.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedProfile = prefs.getString('userProfile');
    if (cachedProfile != null && mounted) {
      final userJson = jsonDecode(cachedProfile);
      setState(() {
        _user = UserModel.fromJson(userJson);
        _stepsToShow = _user?.todaysStepCount ?? 0;
        _isLoading = false;
      });
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final loadedUser = await _authService.refreshUserProfile(currentUser.uid);
    if (loadedUser != null && mounted) {
      final lastOpenDate = prefs.getString('lastOpenDate');
      final today = DateTime.now().toIso8601String().split('T').first;
      final isNewDay = lastOpenDate != today;
      UserModel userToDisplay = loadedUser;
      if (isNewDay) {
        print("New day detected. Resetting UI stats and clearing step offset.");
        await prefs.remove('dailyStepOffset');
        final zeroedStats = Map<String, dynamic>.from(loadedUser.stats ?? {});
        zeroedStats['battlesWon'] = 0;
        zeroedStats['knockouts'] = 0;
        zeroedStats['totalBattles'] = 0;

        userToDisplay = loadedUser.copyWith(
          todaysStepCount: 0,
          stats: zeroedStats,
        );
        await prefs.setString('lastOpenDate', today);
      }
      if (mounted) {
        setState(() {
          _user = userToDisplay;
          _stepsToShow = userToDisplay.todaysStepCount ?? 0;
          _isLoading = false;
        });
      }
      _initStepCounter();
    }
  }

  void _initStepCounter() async {
    _stepSubscription?.cancel();
    final prefs = await SharedPreferences.getInstance();
    _healthService.initialize();
    _stepSubscription = _healthService.stepStream.listen(
      (stepsStr) {
        final currentPedometerReading = int.tryParse(stepsStr);
        if (currentPedometerReading == null) return;
        int? dailyStepOffset = prefs.getInt('dailyStepOffset');
        if (dailyStepOffset == null && _user != null) {
          final dbSteps = _user!.todaysStepCount ?? 0;
          dailyStepOffset = currentPedometerReading - dbSteps;
          prefs.setInt('dailyStepOffset', dailyStepOffset);
          print(
              "Daily Step Offset PERSISTED: $dailyStepOffset (Pedometer: $currentPedometerReading, DB: $dbSteps)");
        }
        if (dailyStepOffset == null) return;
        final calculatedDailySteps = currentPedometerReading - dailyStepOffset;
        final stepsToSave = calculatedDailySteps > 0 ? calculatedDailySteps : 0;

        if (mounted) {
          setState(() {
            _stepsToShow = stepsToSave;
          });
        }

        _debounce?.cancel();
        _debounce = Timer(
            const Duration(seconds: 5), () => _saveLatestSteps(stepsToSave));
      },
    );
  }

  Future<void> _saveLatestSteps(int stepsToSave) async {
    final userToSave = _user;
    if (userToSave == null || userToSave.userId.isEmpty) {
      print("Skipping save: User data is not available.");
      return;
    }

    print(
        "Saving calculated step count: $stepsToSave for user ${userToSave.userId}");

    try {
      await _authService.syncStepsToBackend(userToSave.userId, stepsToSave);
      await _authService
          .updateUserProfile(userToSave.copyWith(todaysStepCount: stepsToSave));
      print("✅ Successfully saved steps to both services.");
    } catch (e) {
      print("❌ Error saving step count: $e");
    }
  }

  Future<void> _startBotBattle() async {
    if (_user == null) {
      _showErrorSnackbar('Could not load user profile.');
      return;
    }
    setState(() => _isCreatingBotGame = true);
    try {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BotSelectionScreen(user: _user!)),
        );
      }
    } catch (e) {
      _showErrorSnackbar('Failed to start game: $e');
    } finally {
      if (mounted) {
        setState(() => _isCreatingBotGame = false);
      }
    }
  }

  void _showFriendBattleDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: const Text('Battle a Friend',
            style: TextStyle(color: Colors.white)),
        content: const Text('Create a new battle or join an existing one.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleStartFriendBattle();
            },
            child: const Text('Start Battle',
                style: TextStyle(color: Color(0xFFFFC107))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleJoinFriendBattle();
            },
            child: const Text('Join Battle',
                style: TextStyle(color: Color(0xFFFFC107))),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStartFriendBattle() async {
    if (_user == null) return;
    setState(() => _isHandlingFriendGame = true);
    try {
      final gameId = await _gameService.createFriendGame(_user!);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                WaitingForFriendScreen(gameId: gameId, user: _user!),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackbar('Failed to create game: $e');
    } finally {
      if (mounted) setState(() => _isHandlingFriendGame = false);
    }
  }

  void _handleJoinFriendBattle() {
    final gameIdController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: const Text('Join Battle', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: gameIdController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Enter Game ID',
            labelStyle: TextStyle(color: Colors.white70),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFFFC107)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              final gameId = gameIdController.text.trim();
              if (gameId.isNotEmpty) {
                Navigator.of(ctx).pop();
                _joinGameById(gameId);
              }
            },
            child:
                const Text('Join', style: TextStyle(color: Color(0xFFFFC107))),
          ),
        ],
      ),
    );
  }

  Future<void> _joinGameById(String gameId) async {
    if (_user == null) return;
    setState(() => _isHandlingFriendGame = true);
    try {
      final success = await _gameService.joinFriendGame(gameId, _user!);
      if (success) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BattleScreen(gameId: gameId, user: _user!),
            ),
          );
        }
      } else {
        _showErrorSnackbar('Could not join game. It might be full or invalid.');
      }
    } catch (e) {
      _showErrorSnackbar('Error joining game: $e');
    } finally {
      if (mounted) setState(() => _isHandlingFriendGame = false);
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.yellow));
    }
    if (_user == null) {
      return const Center(
          child: Text("Could not load user profile. Please restart the app."));
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: Colors.yellow,
        backgroundColor: Colors.grey.shade900,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
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
              const GameRulesWidget(),
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
          child: Row(
            children: [
              const Image(
                  image: AssetImage('assets/images/coin_icon.png'),
                  width: 24,
                  height: 24),
              const SizedBox(width: 8),
              Text(
                _user?.coins?.toString() ?? '0',
                style: const TextStyle(
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
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Today's Steps",
                    style: TextStyle(color: Colors.black, fontSize: 18)),
                const SizedBox(height: 8),
                Text(
                  _stepsToShow.toString(),
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 42,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Icon(Icons.directions_walk, size: 60, color: Colors.black),
        ],
      ),
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
    final stats = _user?.stats ?? {};
    final battlesWon = stats['battlesWon']?.toString() ?? '0';
    final knockouts = stats['knockouts']?.toString() ?? '0';
    final totalBattles = stats['totalBattles']?.toString() ?? '0';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildScorecardItem(
            'assets/images/battle_won.png', battlesWon, 'Battle won'),
        _buildScorecardItem('assets/images/ko_won.png', knockouts, 'Knockouts'),
        _buildScorecardItem(
            'assets/images/coin_won.png', totalBattles, 'Total Battles'),
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
          onTap: _isCreatingBotGame ? null : _startBotBattle,
          isLoading: _isCreatingBotGame,
        ),
        const SizedBox(width: 16),
        _buildBattleOption(
          'Battle a Friend',
          'assets/images/battle_friend.png',
          onTap: _showFriendBattleDialog,
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
