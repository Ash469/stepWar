import 'dart:async';
import 'package:flutter/material.dart';
import '../models/battle_RB.dart';
import '../models/user_model.dart';
import '../services/game_service.dart';
import '../services/bot_service.dart';
import '../services/step_counting.dart';
import 'dart:math' as math;

class BattleScreen extends StatefulWidget {
  final String gameId;
  final UserModel user;
  const BattleScreen({super.key, required this.gameId, required this.user});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  final GameService _gameService = GameService();
  final BotService _botService = BotService();
  final HealthService _healthService = HealthService();

  StreamSubscription? _gameSubscription;
  StreamSubscription? _stepSubscription;
  Timer? _botStepTimer;
  Timer? _gameTimer;

  Game? _currentGame;
  bool _isLoading = true;
  int _initialPlayerSteps = -1;
  Duration _timeLeft = const Duration(minutes: 60);

  @override
  void initState() {
    super.initState();
    _listenToGameUpdates();
    _initializeServices();
  }

  @override
  void dispose() {
    _gameSubscription?.cancel();
    _stepSubscription?.cancel();
    _botStepTimer?.cancel();
    _gameTimer?.cancel();
    _healthService.dispose();
    super.dispose();
  }

  void _listenToGameUpdates() {
    _gameSubscription =
        _gameService.getGameStream(widget.gameId).listen((game) {
      if (mounted) {
        if (_isLoading) setState(() => _isLoading = false);
        if (_currentGame == null && game?.startTime != null) {
          _startGameTimer(game!.startTime!);
        }
        if (game?.gameStatus == GameStatus.completed &&
            _currentGame?.gameStatus != GameStatus.completed) {
          _showGameOverDialog(game);
        }
        setState(() => _currentGame = game);
      }
    });
  }

  void _startGameTimer(int startTimeMillis) {
    final startTime = DateTime.fromMillisecondsSinceEpoch(startTimeMillis);
    const gameDuration = Duration(minutes: 60);
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed >= gameDuration) {
        timer.cancel();
        if (mounted) setState(() => _timeLeft = Duration.zero);
        _endGame();
      } else {
        if (mounted) setState(() => _timeLeft = gameDuration - elapsed);
      }
    });
  }

  void _initializeServices() {
    _healthService.initialize();
    _stepSubscription = _healthService.stepStream.listen(
      _onPlayerStep,
      onError: (error) => print("Step Stream Error: $error"),
    );
    _botStepTimer =
        Timer.periodic(const Duration(seconds: 1), _updateBotState);
  }

  void _onPlayerStep(String stepsStr) {
    if (_currentGame?.gameStatus == GameStatus.completed) return;
    final currentTotalSteps = int.tryParse(stepsStr);
    if (currentTotalSteps == null || _currentGame == null) return;
    if (_initialPlayerSteps == -1) _initialPlayerSteps = currentTotalSteps;
    final stepsThisGame = currentTotalSteps - _initialPlayerSteps;
    if (stepsThisGame >= 0 && stepsThisGame != _currentGame!.step1Count) {
      _gameService.updatePlayerSteps(widget.gameId, stepsThisGame);
    }
  }

  void _updateBotState(Timer timer) {
    if (_currentGame == null ||
        _currentGame!.player2Id == null ||
        _currentGame?.gameStatus == GameStatus.completed) return;
    final botId = _currentGame!.player2Id!;
    final botType = _botService.getBotTypeFromId(botId);
    if (botType != null) {
      final generatedSteps = _botService.generateStepsForOneSecond(botType);
      final newBotSteps = _currentGame!.step2Count + generatedSteps;
      _gameService.updateGame(widget.gameId,
          {'step2_count': newBotSteps, 'player2_score': newBotSteps});
    }
  }

  void _endGame() {
    if (_currentGame == null ||
        _currentGame!.gameStatus == GameStatus.completed) return;
    int p1 = _currentGame!.step1Count;
    int p2 = _currentGame!.step2Count;
    GameResult result;
    String? winnerId;
    if ((p1 - p2).abs() <= 100) {
      result = GameResult.draw;
    } else if (p1 > p2) {
      winnerId = _currentGame!.player1Id;
      result = (p1 - p2) >= 3000 ? GameResult.KO : GameResult.win;
    } else {
      winnerId = _currentGame!.player2Id;
      result = (p2 - p1) >= 3000 ? GameResult.KO : GameResult.win;
    }
    _gameService.updateGame(widget.gameId, {
      'gameStatus': GameStatus.completed.name,
      'winner': winnerId,
      'result': result.name
    });
  }

  void _showGameOverDialog(Game? game) {
    if (!mounted || game == null) return;
    String title;
    String content;
    if (game.result == GameResult.draw || game.winner == null) {
      title = "It's a Draw!";
      content = "The battle ended in a stalemate.";
    } else if (game.winner == widget.user.userId) {
      title = "Congratulations!";
      content = "You won the battle!";
    } else {
      title = "You Lost!";
      content = "Better luck next time.";
    }
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF2a2a2a),
              title: Text(title, style: const TextStyle(color: Colors.white)),
              content:
                  Text(content, style: const TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                    child: const Text('Go to Home',
                        style: TextStyle(color: Color(0xFFFFC107))),
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst)),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _currentGame == null) {
      return const Scaffold(
          backgroundColor: Color(0xFF1E1E1E),
          body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFFC107))));
    }
    if (_currentGame!.player2Id == null) {
      return const Scaffold(
          backgroundColor: Color(0xFF1E1E1E),
          body: Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFFFC107)),
              SizedBox(height: 16),
              Text("Waiting for opponent...",
                  style: TextStyle(color: Colors.white70)),
            ],
          )));
    }

    final botName = _botService.getBotNameFromId(_currentGame!.player2Id!);
    final playerName = widget.user.username ?? "You";

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTimer(),
              _buildPlayerStats(playerName, botName),
              _buildBattleBar(),
              _buildMultiplierSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimer() {
    String minutes =
        _timeLeft.inMinutes.remainder(60).toString().padLeft(2, '0');
    String seconds =
        _timeLeft.inSeconds.remainder(60).toString().padLeft(2, '0');
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

  Widget _buildPlayerStats(String playerName, String botName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildPlayerCard(
            playerName,
            _currentGame!.step1Count,
            widget.user.profileImageUrl,
            _currentGame!.multiplier1,
            true),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.0),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFF333333),
            child: Text('VS',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        _buildPlayerCard(botName, _currentGame!.step2Count, null,
            _currentGame!.multiplier2, false),
      ],
    );
  }

  Widget _buildPlayerCard(
      String name, int steps, String? imageUrl, double multiplier, bool isYou) {
    return Expanded(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.grey.shade800,
                backgroundImage:
                    imageUrl != null ? NetworkImage(imageUrl) : null,
                child: imageUrl == null
                    ? const Icon(Icons.smart_toy,
                        size: 35, color: Colors.white70)
                    : null,
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
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
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
          Text(
            steps.toString(),
            style: const TextStyle(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          const Text('Total steps',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Text(name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildBattleBar() {
    final p1 = _currentGame!.step1Count;
    final p2 = _currentGame!.step2Count;
    final diff = p1 - p2;

    String statusText;
    Color statusColor;
    if (diff.abs() <= 100) {
      statusText = 'Even Match';
      statusColor = Colors.white;
    } else {
      statusText = 'Ahead by ${diff.abs()} steps';
      statusColor = diff > 0 ? const Color(0xFF69F0AE) : Colors.yellow.shade700;
    }

    // Normalize diff from -3000 to 3000 to a 0.0 to 1.0 scale
    double normalizedValue = (diff.clamp(-3000, 3000) + 3000) / 6000;

    return Column(
      children: [
        Text(
          statusText,
          style: TextStyle(
              color: statusColor, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, constraints) {
          final barWidth = constraints.maxWidth;
          return SizedBox(
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The main progress bar
                Container(
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1565C0),
                        Color(0xFF42A5F5),
                        Color(0xFF616161),
                        Color(0xFFEF5350),
                        Color(0xFFB71C1C),
                      ],
                      stops: [0.0, 0.4, 0.5, 0.6, 1.0],
                    ),
                  ),
                ),
                // Draw text in the middle
                const Positioned(
                  child: Text(
                    "DRAW",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                // The marker
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  left: (barWidth - 30) * normalizedValue,
                  child: Column(
                    children: [
                      Transform.rotate(
                        angle: math.pi,
                        child: const Icon(Icons.arrow_drop_down,
                            color: Color(0xFFFFC107), size: 30),
                      ),
                      Container(
                        width: 4,
                        height: 30,
                        color: const Color(0xFFFFC107),
                      ),
                    ],
                  ),
                ),

                // Win and KO icons
                const Positioned(
                    left: 12,
                    child: Column(
                      children: [
                        Icon(Icons.emoji_events,
                            color: Colors.amber, size: 20),
                        Text("Win",
                            style:
                                TextStyle(color: Colors.white, fontSize: 10)),
                      ],
                    )),
                const Positioned(
                    right: 12,
                    child: Column(
                      children: [
                        Icon(Icons.sentiment_very_dissatisfied,
                            color: Colors.yellow, size: 20),
                        Text("KO",
                            style:
                                TextStyle(color: Colors.white, fontSize: 10)),
                      ],
                    )),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        // Labels below the bar
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('3k', style: TextStyle(color: Colors.white70)),
              Text('2k', style: TextStyle(color: Colors.white70)),
              Text('1k', style: TextStyle(color: Colors.white70)),
              SizedBox(width: 20),
              Text('-1k', style: TextStyle(color: Colors.white70)),
              Text('-2k', style: TextStyle(color: Colors.white70)),
              Text('-3k', style: TextStyle(color: Colors.white70)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildMultiplierSection() {
    return Column(
      children: [
        const Text('Buy Steps multiplier',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 16),
        Container(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white30, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMultiplierButton('1.5X', false),
              Container(width: 1, color: Colors.white30),
              _buildMultiplierButton('2X', false),
              Container(width: 1, color: Colors.white30),
              _buildMultiplierButton('3X', false),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildMultiplierButton(String text, bool isActive) {
    return Expanded(
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFFC107) : Colors.transparent,
          borderRadius: text == '1.5X'
              ? const BorderRadius.only(
                  topLeft: Radius.circular(11), bottomLeft: Radius.circular(11))
              : text == '3X'
                  ? const BorderRadius.only(
                      topRight: Radius.circular(11),
                      bottomRight: Radius.circular(11))
                  : BorderRadius.zero,
        ),
        child: Center(
          child: Text(text,
              style: TextStyle(
                  color: isActive ? Colors.black : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

