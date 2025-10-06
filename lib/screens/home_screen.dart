import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stepwars_app/services/active_battle_service.dart';
import 'package:stepwars_app/services/bot_service.dart';
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
  final BotService _botService = BotService();

  UserModel? _user;
  UserModel? _opponentProfile;
  bool _isLoading = true;
  StreamSubscription? _stepSubscription;
  Timer? _debounce;
  bool _isCreatingBotGame = false;
  bool _isHandlingFriendGame = false;
  int _stepsToShow = 0;
  bool _isFetchingOpponent = false;

  bool _isCreatingGame = false;

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

  Future<void> _fetchOpponentProfile(ActiveBattleService battleService) async {
    if (_isFetchingOpponent ||
        _opponentProfile != null ||
        battleService.currentGame == null) return;

    setState(() => _isFetchingOpponent = true);

    final game = battleService.currentGame!;
    final isUserPlayer1 = game.player1Id == _user!.userId;
    final opponentId = isUserPlayer1 ? game.player2Id : game.player1Id;

    UserModel? opponent;
    if (opponentId != null && opponentId.isNotEmpty) {
      if (opponentId.startsWith('bot_')) {
        final botType = _botService.getBotTypeFromId(opponentId);
        if (botType != null) {
          opponent = UserModel(
            userId: opponentId,
            username: _botService.getBotNameFromId(opponentId),
            profileImageUrl: _botService.getBotImagePath(botType),
          );
        }
      } else {
        opponent = await _authService.getUserProfile(opponentId);
      }
    }
    if (mounted) {
      setState(() {
        _opponentProfile = opponent;
        _isFetchingOpponent = false;
      });
    }
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
      setState(() {
        _user = loadedUser;
        _stepsToShow = loadedUser.todaysStepCount ?? 0;
        _isLoading = false;
      });
    }
    _initStepCounter();
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
      context.read<ActiveBattleService>().startBattle(gameId, _user!);
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
        context.read<ActiveBattleService>().startBattle(gameId, _user!);
        if (mounted) {
          // Navigator.of(context).push(
          //   MaterialPageRoute(
          //     builder: (_) => BattleScreen(gameId: gameId, user: _user!),
          //   ),
          // );
          if (mounted) {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const BattleScreen()));
          }
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
              const SizedBox(height: 16),
              _buildBattleSection(),
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
          onTap: _isCreatingGame
              ? null
              : () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => BotSelectionScreen(user: _user!)));
                },
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

  Widget _buildBattleSection() {
    final battleService = context.watch<ActiveBattleService>();

    if (battleService.isBattleActive) {
      if (battleService.isWaitingForFriend) {
        return _buildWaitingForFriendCard(battleService);
      }

      // If it's not waiting, it must be ongoing
      if (battleService.currentGame != null && _opponentProfile == null) {
        _fetchOpponentProfile(battleService);
      }

      if (battleService.currentGame == null || _opponentProfile == null) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Center(child: CircularProgressIndicator(color: Colors.yellow)),
        );
      }
      return _buildOngoingBattleCard(battleService);
    } else {
      _opponentProfile = null; // Clear opponent profile when battle ends
      return Column(
        children: [
          const SizedBox(height: 24),
          _buildSectionTitle("---------- Start A Battle ----------"),
          const SizedBox(height: 16),
          _buildBattleOptions(),
        ],
      );
    }
  }

  Widget _buildWaitingForFriendCard(ActiveBattleService battleService) {
    final gameId = battleService.currentGame?.gameId ?? '...';

    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Card(
        color: const Color(0xFF2a2a2a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text("Waiting for Friend",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.yellow),
                  SizedBox(width: 16),
                  Text("Share the Game ID with your friend",
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 12),
              SelectableText(
                gameId,
                style: const TextStyle(
                    color: Colors.yellow,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2),
              ),
              const Divider(color: Colors.white24, height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      battleService.cancelFriendBattle();
                    },
                    child: const Text("Cancel Battle",
                        style:
                            TextStyle(color: Colors.redAccent, fontSize: 16)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => WaitingForFriendScreen(
                              gameId: gameId, user: _user!)));
                    },
                    child: const Text("Return to Lobby"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOngoingBattleCard(ActiveBattleService battleService) {
    final game = battleService.currentGame!;
    final timeLeft = battleService.timeLeft;
    final isUserPlayer1 = game.player1Id == _user!.userId;

    final player1 = isUserPlayer1 ? _user! : _opponentProfile!;
    final player2 = isUserPlayer1 ? _opponentProfile! : _user!;
    final p1Steps = game.step1Count;
    final p2Steps = game.step2Count;
    final p1Score = game.player1Score;
    final p2Score = game.player2Score;

    final scoreDiff = p1Score - p2Score;
    final userIsAhead = isUserPlayer1 ? scoreDiff > 0 : scoreDiff < 0;
    final aheadByText = userIsAhead
        ? "Ahead by ${scoreDiff.abs()} steps"
        : "Behind by ${scoreDiff.abs()} steps";

    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Card(
        color: const Color(0xFF2a2a2a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text("Ongoing Battle",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${timeLeft.inMinutes.toString().padLeft(2, '0')}:${(timeLeft.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                      const Text("Time left",
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                  Text(
                    aheadByText,
                    style: TextStyle(
                        color:
                            userIsAhead ? Colors.greenAccent : Colors.redAccent,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                // alignItems: CrossAxisAlignment.center,
                children: [
                  _buildPlayerAvatar(player1, p1Steps, game.multiplier1),
                  const Text("VS",
                      style: TextStyle(color: Colors.white54, fontSize: 20)),
                  _buildPlayerAvatar(player2, p2Steps, game.multiplier2),
                ],
              ),
              const SizedBox(height: 20),
              // You can add multiplier buttons here if desired
              const Divider(color: Colors.white24),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BattleScreen()));
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("View full details",
                        style: TextStyle(color: Colors.yellow, fontSize: 16)),
                    Icon(Icons.chevron_right, color: Colors.yellow),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerAvatar(UserModel player, int steps, double multiplier) {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundImage: player.profileImageUrl != null &&
                  player.profileImageUrl!.startsWith('http')
              ? NetworkImage(player.profileImageUrl!)
              : (player.profileImageUrl != null
                  ? AssetImage(player.profileImageUrl!)
                  : null) as ImageProvider?,
          child: player.profileImageUrl == null
              ? const Icon(Icons.person, size: 35)
              : null,
        ),
        const SizedBox(height: 8),
        Text(steps.toString(),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const Text("Total steps",
            style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(player.username ?? 'Player',
            style: const TextStyle(color: Colors.white)),
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
