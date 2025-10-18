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
import 'matchmaking_screen.dart'; 
import '../widget/game_rules.dart';
import '../services/notification_service.dart';
import '../services/mystery_box_service.dart';
import 'kingdom_screen.dart' show KingdomItem;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final HealthService _healthService = HealthService();
  final GameService _gameService = GameService();
  final BotService _botService = BotService();
  final NotificationService _notificationService = NotificationService();
  final MysteryBoxService _mysteryBoxService = MysteryBoxService();

  UserModel? _user;
  UserModel? _opponentProfile;
  bool _isLoading = true;
  StreamSubscription? _stepSubscription;
  Timer? _debounce;
  final bool _isCreatingBotGame = false;
  bool _isHandlingFriendGame = false;
  int _stepsToShow = 0;
  bool _isFetchingOpponent = false;
  final bool _isCreatingGame = false;
  bool _isOpeningBronzeBox = false;
  bool _isOpeningSilverBox = false;
  bool _isOpeningGoldBox = false;
  Timer? _boxTimer;
  Duration _bronzeTimeLeft = Duration.zero;
  Duration _silverTimeLeft = Duration.zero;
  Duration _goldTimeLeft = Duration.zero;
  KingdomItem? _latestReward;

  @override
  void initState() {
    super.initState();
    _loadData();
    _handleNotifications();
    WidgetsBinding.instance.addObserver(this);
    _startBoxTimers();
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    _debounce?.cancel();
    _healthService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _boxTimer?.cancel();
    super.dispose();
  }

  void _startBoxTimers() {
    _boxTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _user?.mysteryBoxLastOpened == null) return;
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      setState(() {
        _bronzeTimeLeft = _calculateTimeLeft('bronze', tomorrow);
        _silverTimeLeft = _calculateTimeLeft('silver', tomorrow);
        _goldTimeLeft = _calculateTimeLeft('gold', tomorrow);
      });
    });
  }

  Duration _calculateTimeLeft(String boxType, DateTime tomorrow) {
    final lastOpenedString = _user?.mysteryBoxLastOpened?[boxType];
    if (lastOpenedString == null) return Duration.zero;
    final lastOpenedDate = DateTime.parse(lastOpenedString).toLocal();
    final now = DateTime.now();

    if (lastOpenedDate.year == now.year &&
        lastOpenedDate.month == now.month &&
        lastOpenedDate.day == now.day) {
      final timeLeft = tomorrow.difference(now);
      return timeLeft.isNegative ? Duration.zero : timeLeft;
    }
    return Duration.zero;
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      print("App resumed, reloading data...");
      _loadData();
      _handleNotifications();
    }
  }

  Future<void> _openMysteryBox(String boxType, int price) async {
    if (_user == null) return;
    final canAfford = (_user!.coins ?? 0) >= price;
    if (!canAfford) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You don't have enough coins!"), backgroundColor: Colors.red),
      );
      return;
    }
    final confirmed = await _showConfirmationDialog(boxType, price);
    if (confirmed != true) return;
    setState(() {
      if (boxType == 'bronze') _isOpeningBronzeBox = true;
      if (boxType == 'silver') _isOpeningSilverBox = true;
      if (boxType == 'gold') _isOpeningGoldBox = true;
    });
    try {
      final reward = await _mysteryBoxService.openMysteryBox(_user!.userId, boxType); 
      final newCoinBalance = reward['newCoinBalance'] as int?;
      if (newCoinBalance != null) {
          setState(() {
              _user = _user!.copyWith(coins: newCoinBalance);
          });
          await _authService.saveUserSession(_user!);
      }  
      _showRewardDialog(reward);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst("Exception: ", "")), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (boxType == 'bronze') _isOpeningBronzeBox = false;
          if (boxType == 'silver') _isOpeningSilverBox = false;
          if (boxType == 'gold') _isOpeningGoldBox = false;
          _loadData(forceRefresh: true);
        });
      }
    }
  }

  Future<bool?> _showConfirmationDialog(String boxType, int price) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: const Text('Confirm Purchase', style: TextStyle(color: Colors.white)),
        content: Text('Open the ${boxType.capitalize()} box for $price coins?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm', style: TextStyle(color: Color(0xFFFFC107))),
          ),
        ],
      ),
    );
  }

  void _showRewardDialog(Map<String, dynamic> reward) {
      String title = "Congratulations!";
      String content = "";

      switch (reward['type']) {
          case 'coins':
              content = "You found ${reward['amount']} coins!";
              break;
          case 'multiplier':
              content = "You received a ${reward['multiplierType']} multiplier token!";
              break;
          case 'collectible':
              final itemName = reward['item']?['name'] ?? 'a new item';
              content = "You unlocked a new collectible: $itemName!";
              break;
          default:
              content = "You've received a special reward!";
      }
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF2a2a2a),
              title: Text(title, style: const TextStyle(color: Colors.white)),
              content: Text(content, style: const TextStyle(color: Colors.white70)),
              actions: [
                  TextButton(
                      child: const Text('Awesome!', style: TextStyle(color: Color(0xFFFFC107))),
                      onPressed: () => Navigator.of(ctx).pop(),
                  ),
              ],
          ),
      );
  }


  Future<void> _handleNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final hasRegisteredToken = prefs.getBool('hasRegisteredFcmToken') ?? false;

    if (hasRegisteredToken) {
      print("[FCM] Token is already registered with backend. Skipping.");
      return;
    }

    final user = _authService.currentUser;
    if (user != null) {
      print("[FCM] Attempting to register FCM token...");
      await _notificationService.initialize();
      final token = await _notificationService.getFcmToken();
      if (token != null) {
        final success = await _notificationService.registerTokenWithBackend(user.uid, token);
        if (success) {
          await prefs.setBool('hasRegisteredFcmToken', true);
          print("[FCM] Token registration successful and flag saved.");
        }
      }
    }
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

  void _setLatestRewardFromData(Map<String, dynamic> rawRewardsMap) {
    if (!mounted) return;
    
    KingdomItem? latest;
    for (var categoryList in rawRewardsMap.values) {
      if (categoryList is List && categoryList.isNotEmpty) {
        final lastItemMap = categoryList.last as Map<String, dynamic>?;
        if (lastItemMap != null) {
          latest = KingdomItem.fromJson(lastItemMap);
          break; 
        }
      }
    }
  
    setState(() {
      _latestReward = latest;
    });
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (_user == null) {
      setState(() => _isLoading = true);
    }
    final prefs = await SharedPreferences.getInstance();
    final currentUser = FirebaseAuth.instance.currentUser;
    final lastOpenDate = prefs.getString('lastOpenDate');
    final today = DateTime.now().toIso8601String().split('T').first;
    final isNewDay = lastOpenDate != today;
    
    final cachedProfile = prefs.getString('userProfile');
    final cachedRewards = prefs.getString('userRewardsCache');

    if (cachedProfile != null && mounted) {
      var user = UserModel.fromJson(jsonDecode(cachedProfile));
      if (isNewDay) {
        print("[Local Reset] New day detected. Resetting UI stats.");
        user = user.copyWith(
          todaysStepCount: 0,
          stats: {'battlesWon': 0, 'knockouts': 0, 'totalBattles': 0},
        );
        await prefs.remove('dailyStepOffset');
        await _authService.saveUserSession(user);
        await prefs.setString('lastOpenDate', today);
      }
      setState(() {
        _user = user;
        _stepsToShow = user.todaysStepCount ?? 0;
        _isLoading = false;
      });
      if (cachedRewards != null && !forceRefresh) {
        _setLatestRewardFromData(Map<String, dynamic>.from(jsonDecode(cachedRewards)));
      }
    }
    if ((isNewDay || forceRefresh || cachedProfile == null) && currentUser != null) {
      print("[Optimized] Fetching latest profile and rewards from server in background...");
      
      try {
        final results = await Future.wait([
          _authService.refreshUserProfile(currentUser.uid),
          _authService.getUserRewards(currentUser.uid) // This returns Map<String, List<dynamic>>
        ]);

        final serverUser = results[0] as UserModel?;
        if (serverUser != null && mounted) {
          setState(() {
            _user = serverUser;
            _stepsToShow = serverUser.todaysStepCount ?? 0;
          });
        }

        // Process rewards
        final rawRewards = results[1] as Map<String, dynamic>?;
        if (rawRewards != null && mounted) {
          await prefs.setString('userRewardsCache', jsonEncode(rawRewards));
          _setLatestRewardFromData(rawRewards);
        }

      } catch (e) {
        print("Error during parallel fetch: $e");
        // Handle error, maybe show a snackbar
      }
    }

    _initStepCounter();
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
  }

   void _initStepCounter() async {
    _stepSubscription?.cancel();
    final prefs = await SharedPreferences.getInstance();
    
    await _healthService.initialize();

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
            const Duration(seconds: 2), () => _saveLatestSteps(stepsToSave));
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
         onRefresh: () => _loadData(forceRefresh: true), 
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
                      builder: (_) => MatchmakingScreen(user: _user!)));
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
      _opponentProfile = null;
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
                children: [
                  _buildPlayerAvatar(player1, p1Steps, game.multiplier1),
                  const Text("VS",
                      style: TextStyle(color: Colors.white54, fontSize: 20)),
                  _buildPlayerAvatar(player2, p2Steps, game.multiplier2),
                ],
              ),
              const SizedBox(height: 20),
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
          radius: 30,
          backgroundColor: Colors.grey.shade800,
          child: player.profileImageUrl == null
              ? const Icon(Icons.person, size: 25)
              : ClipOval(
                  child: player.profileImageUrl!.startsWith('assets/')
                      ? Image.asset(
                          player.profileImageUrl!,
                          fit: BoxFit.contain,
                          width: 80,
                          height: 80,
                        )
                      : Image.network(
                          player.profileImageUrl!,
                          fit: BoxFit.cover,
                          width: 60,
                          height: 60,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.person, size: 25),
                        ),
                ),
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
    if (_latestReward == null) {
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
                Icon(Icons.shield_moon_outlined, color: Colors.grey.shade400, size: 30),
                const SizedBox(width: 12),
                const Text("No Rewards Yet",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Win battles to collect new rewards for your Kingdom!",
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }

    // Show the latest reward
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
              // Use the imagePath from the reward
              _latestReward!.imagePath.isNotEmpty
                ? Image.asset(
                    _latestReward!.imagePath, 
                    height: 30, 
                    errorBuilder: (c, e, s) => Icon(Icons.location_city, color: _latestReward!.rarityColor, size: 30),
                  )
                : Icon(Icons.location_city, color: _latestReward!.rarityColor, size: 30),
              const SizedBox(width: 12),
              // Use the name from the reward
              Text(_latestReward!.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          // Use the description from the reward
          Text(
            _latestReward!.description,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
        _buildMysteryBox(
          imagePath: 'assets/images/bronze_box.png', 
          boxType: 'bronze',
          price: 5000,
          isLoading: _isOpeningBronzeBox,
          timeLeft: _bronzeTimeLeft,
        ),
        _buildMysteryBox(
          imagePath: 'assets/images/silver_box.png', 
          boxType: 'silver',
          price: 10000,
          isLoading: _isOpeningSilverBox,
          timeLeft: _silverTimeLeft,
        ),
        _buildMysteryBox(
          imagePath: 'assets/images/gold_box.png', 
          boxType: 'gold',
          price: 20000,
          isLoading: _isOpeningGoldBox,
          timeLeft: _goldTimeLeft,
        ),
      ],
    );
  }

  Widget _buildMysteryBox({
    required String imagePath, 
    required String boxType,
    required int price,
    required bool isLoading,
    required Duration timeLeft,
  }) {
    final bool isOpenedToday = timeLeft > Duration.zero;

    return Expanded(
      child: GestureDetector(
        onTap: (isOpenedToday || isLoading) ? null : () => _openMysteryBox(boxType, price),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      imagePath,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    if (isLoading)
                      const CircularProgressIndicator(color: Colors.white),
                    if (isOpenedToday && !isLoading)
                      Container(
                        height: 120,
                        width: double.infinity,
                        color: Colors.black.withOpacity(0.6),
                        child: const Icon(Icons.lock_clock, color: Colors.white, size: 40),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isOpenedToday ? Colors.transparent : Colors.yellow.shade800,
                  borderRadius: BorderRadius.circular(20),
                  border: isOpenedToday ? Border.all(color: Colors.grey.shade700) : null,
                ),
                child: isOpenedToday 
                  ? Text(
                      _formatDuration(timeLeft),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
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
                          price.toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
    String capitalize() {
      return "${this[0].toUpperCase()}${this.substring(1)}";
    }
}