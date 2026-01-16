// ignore_for_file: unused_local_variable
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/battle_rb.dart';
import '../services/active_battle_service.dart';
import '../services/auth_service.dart';
import '../services/bot_service.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'main_screen.dart';

class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  UserModel? _currentUserModel;
  UserModel? _opponentProfile;
  bool _isFetchingData = false;
  final BotService _botService = BotService();
  bool _isEndingBattle = false;
  StreamSubscription? _battleStreamSubscription; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchBattleDataIfNeeded();
    });
    final battleService = context.read<ActiveBattleService>();
    _battleStreamSubscription = battleService.stream.listen((_) {
      if (battleService.finalBattleState != null && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _battleStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchBattleDataIfNeeded() async {
    if (mounted &&
        (_isFetchingData ||
            (_currentUserModel != null && _opponentProfile != null))) {
      return;
    }
    if (mounted) {
      setState(() {
        _isFetchingData = true;
      });
    }
    final battleService = context.read<ActiveBattleService>();
    final authService = context.read<AuthService>();
    final game = battleService.currentGame;
    final currentUserId = authService.currentUser?.uid;
    if (game == null || currentUserId == null) {
      if (mounted) setState(() => _isFetchingData = false);
      return;
    }
    final currentUserProfile = await authService.getUserProfile(currentUserId);
    final isUserPlayer1 = game.player1Id == currentUserId;
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
      } else if (opponentId == 'dummy_player_test_01') {
        opponent = UserModel(
          userId: opponentId,
          username: 'Test Opponent',
          profileImageUrl: null,
        );
      } else {
        opponent = await authService.getUserProfile(opponentId);
      }
    }
    if (mounted) {
      setState(() {
        _currentUserModel = currentUserProfile;
        _opponentProfile = opponent;
        _isFetchingData = false;
      });
    }
  }

  Future<void> _refreshCurrentUserProfile() async {
    if (_currentUserModel == null || !mounted) return;

    final authService = context.read<AuthService>();
    final updatedUser =
        await authService.refreshUserProfile(_currentUserModel!.userId);

    if (updatedUser != null && mounted) {
      setState(() {
        _currentUserModel = updatedUser;
      });
      print(
          "Battle screen coin count updated via setState to: ${updatedUser.coins}");
    } else {
      print("Failed to refresh user profile on battle screen.");
    }
  }

  Future<void> _activateMultiplier(String multiplierType) async {
    final battleService = context.read<ActiveBattleService>();
    final userId = _currentUserModel?.userId;
    if (userId == null) return;
    try {
      await battleService.activateMultiplier(multiplierType, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$multiplierType Multiplier Activated!'),
              backgroundColor: Colors.green),
        );
        await _refreshCurrentUserProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString().replaceFirst("Exception: ", "")),
              backgroundColor: Colors.red),
        );
      }
    }
  }

    Future<void> _showEndBattleConfirmation() async {
    final battleService = context.read<ActiveBattleService>();
    if (_isEndingBattle || battleService.isEndingBattle) return;

    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: const Text('End Battle?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to end the battle? This will be counted as a loss.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('End Battle',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (didConfirm == true && mounted) {
      setState(() => _isEndingBattle = true);
      try {
       await battleService.forfeitBattle();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error ending battle: $e'),
                backgroundColor: Colors.red),
          );
          setState(() => _isEndingBattle = false);
        }
      }
    }
  }

  Widget _buildYourRewardsSection(Game game) {
    final potentialReward = game.potentialReward;
    if (potentialReward == null || potentialReward.isEmpty) {
      return const SizedBox.shrink();
    }

    final String? imagePath = potentialReward['imagePath'];
    final String? rewardName = potentialReward['name'];
    final String? rewardTier = potentialReward['tier'];
    final String? rewardDes = potentialReward['description'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text("Your Potential Reward",
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2a2a2a),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              imagePath != null && imagePath.isNotEmpty
                  ? Image.network(imagePath, fit: BoxFit.contain, width: 40, height: 40)
                  : const Icon(Icons.shield, color: Colors.white70, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rewardName ?? 'Mystery Reward',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "${rewardTier ?? ''} reward!",
                      style: const TextStyle(
                          color: Colors.white70, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      rewardDes ?? '',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final battleService = context.watch<ActiveBattleService>();
    if (battleService.currentGame != null &&
        !_isFetchingData &&
        (_currentUserModel == null || _opponentProfile == null)) {
      _fetchBattleDataIfNeeded();
    }
    if (battleService.isEndingBattle) {
      return const Scaffold(
          backgroundColor: Color(0xFF1E1E1E),
          body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFFC107))));
    }
    if (!battleService.isBattleActive ||
        battleService.currentGame == null ||
        _currentUserModel == null ||
        _opponentProfile == null) {
      return const Scaffold(
          backgroundColor: Color(0xFF1E1E1E),
          body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFFC107))));
    }
    final remoteConfig = context.read<FirebaseRemoteConfig>();
    final game = battleService.currentGame!;
    final isUserPlayer1 = game.player1Id == _currentUserModel!.userId;
    final player1 = isUserPlayer1 ? _currentUserModel! : _opponentProfile!;
    final player2 = isUserPlayer1 ? _opponentProfile! : _currentUserModel!;
    final p1Score = game.player1Score;
    final p2Score = game.player2Score;
    final p1Steps = game.step1Count;
    final p2Steps = game.step2Count;
    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text('Ongoing Battle',
              style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Chip(
                backgroundColor: const Color(0xFF333333),
                avatar: Image.asset('assets/images/coin_icon.png'),
                label: Text(
                  _currentUserModel!.coins?.toString() ?? '0',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTopSection(
                    battleService, p1Score, p2Score, isUserPlayer1),
                _buildPlayerStats(
                    player1, p1Score, p1Steps, player2, p2Score, p2Steps, game),
                _buildBattleBar(p1Score, p2Score),
                _buildMultiplierSection(isUserPlayer1, game, _currentUserModel!, remoteConfig),
                _buildYourRewardsSection(game),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection(ActiveBattleService battleService, int p1Score,
      int p2Score, bool isUserP1) {
    final timeLeft = battleService.timeLeft;
    final minutes = timeLeft.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = timeLeft.inSeconds.remainder(60).toString().padLeft(2, '0');

    final scoreDiff = isUserP1 ? (p1Score - p2Score) : (p2Score - p1Score);
    final bool isAhead = scoreDiff > 0;
    final bool isDraw = scoreDiff.abs() <= 50;

    const bool canEndBattle = true; 

    String statusText;
    Color statusColor;

    if (isAhead) {
      statusText = "Ahead by ${scoreDiff.abs()} Score";
      statusColor = Colors.greenAccent;
    } else {
      statusText = "Behind by ${scoreDiff.abs()} Score";
      statusColor = Colors.redAccent;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 80),
            Column(
              children: [
                Text('$minutes:$seconds',
                    style: const TextStyle(
                        color: Color(0xFFE53935),
                        fontSize: 40,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Time left',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
            if (_isEndingBattle)
              const SizedBox(
                width: 80,
                child: Center(
                    child: CircularProgressIndicator(
                        color: Colors.redAccent, strokeWidth: 2)),
              )
            else
              SizedBox(
                width: 80,
                child: Visibility(
                  visible: canEndBattle,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextButton(
                    onPressed: _showEndBattleConfirmation,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                    child: const Text(
                      'End Battle',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(statusText,
            style: TextStyle(
                color: statusColor, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPlayerStats(UserModel player1, int p1Score, int p1Steps,
      UserModel player2, int p2Score, int p2Steps, Game game) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPlayerCard(player1.username ?? 'Player 1', p1Score, p1Steps,
            player1.profileImageUrl, game.multiplier1),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 40.0),
          child: CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFF333333),
              child: Text('VS',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold))),
        ),
        _buildPlayerCard(player2.username ?? 'Player 2', p2Score, p2Steps,
            player2.profileImageUrl, game.multiplier2),
      ],
    );
  }

  Widget _buildPlayerCard(
      String name, int score, int steps, String? imageUrl, double multiplier) {
    return Expanded(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey.shade800,
                child: imageUrl == null
                    ? const Icon(Icons.person, size: 45, color: Colors.white70)
                    : ClipOval(
                        child: imageUrl.startsWith('assets/')
                            ? Image.asset(imageUrl,
                                fit: BoxFit.contain, width: 120, height: 120)
                            : Image.network(imageUrl,
                                fit: BoxFit.cover,
                                width: 120,
                                height: 120,
                                loadingBuilder: (context, child, progress) =>
                                    progress == null
                                        ? child
                                        : const CircularProgressIndicator(),
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.person,
                                        size: 45, color: Colors.white70))),
              ),
              Positioned(
                top: -5,
                left: -5,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFC107),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black, width: 1.5)),
                  child: Text('${multiplier}x',
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(score.toString(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold)),
          const Text('Score',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Text(steps.toString(),
              style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
          Text('Steps',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
          const SizedBox(height: 8),
          Text(name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildBattleBar(int p1Score, int p2Score) {
    final diff = p1Score - p2Score;
    double normalizedValue = (diff.clamp(-200, 200) + 200) / 400;
    return Column(
      children: [
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final barWidth = constraints.maxWidth;
          return SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 25,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: const LinearGradient(colors: [
                      Color(0xFF42A5F5),
                      Color(0xFF373737),
                      Color(0xFFEF5350)
                    ], stops: [
                      0.0,
                      0.5,
                      1.0
                    ]),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  left: (barWidth - 16) * normalizedValue,
                  child: const Icon(Icons.arrow_drop_down,
                      color: Color(0xFFFFC107), size: 24),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                'assets/images/ko_win.png',
                height: 28,
                width: 28,
                errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.shield, color: Color(0xFF42A5F5), size: 28),
                ),
                const SizedBox(height: 6),
                const Text('Win',
                  style: TextStyle(
                    color: Color(0xFF42A5F5), fontWeight: FontWeight.bold)),
              ],
              ),
              Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                'assets/images/ko_loss.png',
                height: 28,
                width: 28,
                errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.shield, color: Color(0xFFEF5350), size: 28),
                ),
                const SizedBox(height: 6),
                const Text("KO",
                  style: TextStyle(
                    color: Color(0xFFEF5350), fontWeight: FontWeight.bold)),
              ],
              ),
            ],
            ),
          ),
         
      ],
    );
  }

 Widget _buildMultiplierSection(
      bool isUserPlayer1, Game game, UserModel currentUser, FirebaseRemoteConfig remoteConfig) {
    final battleService = context.watch<ActiveBattleService>(); // Need context here
    final bool hasUsedMultiplier =
        isUserPlayer1 ? game.player1MultiplierUsed : game.player2MultiplierUsed;

    if (battleService.isActivatingMultiplier) {
      return const Padding( // Add padding for spacing
         padding: EdgeInsets.symmetric(vertical: 20.0),
         child: CircularProgressIndicator(color: Color(0xFFFFC107)),
      );
    }
    if (hasUsedMultiplier) {
      return const Padding( // Add padding for spacing
         padding: EdgeInsets.symmetric(vertical: 20.0),
         child: Text("Multiplier used!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
      );
    }
    final multipliers = currentUser.multipliers ?? {};
    final available1_5x = multipliers['1_5x'] ?? 0;
    final available2x = multipliers['2x'] ?? 0;
    final available3x = multipliers['3x'] ?? 0;
    final cost1_5x = remoteConfig.getInt('multiplier_1_5x_price');
    final cost2x = remoteConfig.getInt('multiplier_2x_price');
    final cost3x = remoteConfig.getInt('multiplier_3x_price');

    return Column(
      children: [
        const Text("Activate a Score Multiplier", style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMultiplierButton('1.5X', '1_5x', cost1_5x, available1_5x),
            _buildMultiplierButton('2X', '2x', cost2x, available2x),
            _buildMultiplierButton('3X', '3x', cost3x, available3x),
          ],
        ),
      ],
    );
  }

  Widget _buildMultiplierButton(
      String displayText, String apiKey, int cost, int available) {
    final bool canUse = available > 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ElevatedButton(
          onPressed: () => _activateMultiplier(apiKey),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF333333),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(displayText,
                  style: const TextStyle(
                      color: Color(0xFFFFC107),
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              if (canUse)
                const Text('Use Token',
                    style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12))
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/coin_icon.png',
                        width: 20, height: 20),
                    const SizedBox(width: 4),
                    Text(cost.toString(),
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
            ],
          ),
        ),
        if (canUse)
          Positioned(
            top: -8,
            right: -8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC107),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 1.5),
              ),
              constraints: const BoxConstraints(
                minWidth: 22,
                minHeight: 22,
              ),
              child: Center(
                child: Text(
                  '$available',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}