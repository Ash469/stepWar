import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/battle_RB.dart';
import '../services/active_battle_service.dart';
import '../services/auth_service.dart';
import '../services/bot_service.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchBattleDataIfNeeded();
    });
  }

  Future<void> _fetchBattleDataIfNeeded() async {
    if (mounted && (_isFetchingData || (_currentUserModel != null && _opponentProfile != null))) return;
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

  Widget _buildYourRewardsSection(Game game) {
  final potentialReward = game.potentialReward;
  if (potentialReward == null || potentialReward.isEmpty) {
    return const SizedBox.shrink();
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 24),
      const Text("Your Potential Reward",
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2a2a2a),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Image.asset('assets/images/mumbai.png', height: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    potentialReward['name'] ?? 'Mystery Reward',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Win the battle to claim this ${potentialReward['tier'] ?? ''} reward!",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
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
    if (battleService.currentGame != null && !_isFetchingData && (_currentUserModel == null || _opponentProfile == null)) {
      _fetchBattleDataIfNeeded();
    }
    if (!battleService.isBattleActive && ModalRoute.of(context)?.isCurrent == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
    }
    if (!battleService.isBattleActive || battleService.currentGame == null || _currentUserModel == null || _opponentProfile == null) {
      return const Scaffold(
          backgroundColor: Color(0xFF1E1E1E),
          body: Center(child: CircularProgressIndicator(color: Color(0xFFFFC107))));
    }
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
            padding: const EdgeInsets.symmetric(
                horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTimer(battleService.timeLeft),
                _buildPlayerStats(player1, p1Score, p1Steps,
                    player2, p2Score, p2Steps, game),
                _buildBattleBar(p1Score, p2Score),
                _buildMultiplierSection(isUserPlayer1, game),
                 _buildYourRewardsSection(game),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimer(Duration timeLeft) {
    final minutes =
        timeLeft.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        timeLeft.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Column(
      children: [
        Text('$minutes:$seconds',
            style: const TextStyle(
                color: Color(0xFFE53935),
                fontSize: 48,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Time left',
            style: TextStyle(color: Colors.white70, fontSize: 16)),
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
    double normalizedValue = (diff.clamp(-1000, 1000) + 1000) / 2000;
    return Column(
      children: [
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, constraints) {
          final barWidth = constraints.maxWidth;
          return SizedBox(
            height: 50,
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your KO',
                  style: TextStyle(
                      color: Color(0xFF42A5F5), fontWeight: FontWeight.bold)),
              Text("Opponent's KO",
                  style: TextStyle(
                      color: Color(0xFFEF5350), fontWeight: FontWeight.bold)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildMultiplierSection(bool isUserPlayer1, Game game) {
    final battleService = context.watch<ActiveBattleService>();
    final bool hasUsedMultiplier = isUserPlayer1
        ? game.player1MultiplierUsed
        : game.player2MultiplierUsed;

    if (battleService.isActivatingMultiplier) {
      return const CircularProgressIndicator(color: Color(0xFFFFC107));
    }
    if (hasUsedMultiplier) {
      return const Text("Multiplier used!",
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
    }
    return Column(
      children: [
        const Text("Buy Steps multiplier",
            style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMultiplierButton('1.5X', '1_5x', 15),
            _buildMultiplierButton('2X', '2x', 20),
            _buildMultiplierButton('3X', '3x', 30),
          ],
        ),
      ],
    );
  }

  Widget _buildMultiplierButton(String displayText, String apiKey, int cost) {
    return ElevatedButton(
      onPressed: () => _activateMultiplier(apiKey),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF333333),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: Column(
        children: [
          Text(displayText,
              style: const TextStyle(
                  color: Color(0xFFFFC107),
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Image(
                  image: AssetImage('assets/images/coin_icon.png'),
                  width: 24,
                  height: 24),
              const SizedBox(width: 4),
              Text(cost.toString(),
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }
}