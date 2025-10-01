import 'dart:async';
import 'package:flutter/material.dart';
import '../models/battle_RB.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
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
  final AuthService _authService = AuthService();

  StreamSubscription? _gameSubscription;
  StreamSubscription? _stepSubscription;
  Timer? _botStepTimer;
  Timer? _gameTimer;

  Game? _currentGame;
  UserModel? _opponentProfile;
  bool _isLoading = true;
  bool _isUserPlayer1 = false;
  bool _isBotMatch = false;
  double _selectedMultiplier = 1.0;

  int _initialPlayerSteps = -1;
  Duration _timeLeft = const Duration(minutes: 60);

  @override
  void initState() {
    super.initState();
    _listenToGameUpdates();
    _initializePlayerStepCounter();
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
        _gameService.getGameStream(widget.gameId).listen((game) async {
      if (mounted) {
        final isFirstLoad = _currentGame == null;
        if (isFirstLoad && game != null) {
          _isUserPlayer1 = widget.user.userId == game.player1Id;
          final opponentId =
              _isUserPlayer1 ? game.player2Id : game.player1Id;
          await _loadOpponentProfile(opponentId);
          if (game.startTime != null) {
            _startGameTimer(game.startTime!);
          }
          if (_isBotMatch && _botStepTimer == null) {
            _initializeBotStepGenerator();
          }
        }

        if (game != null && game.gameStatus == GameStatus.ongoing) {
          final p1Score = game.player1Score;
          final p2Score = game.player2Score;
          if ((p1Score - p2Score).abs() >= 1000) { //KO Logic
            _endGame(isKO: true);
          }
        }

        if (game?.gameStatus == GameStatus.completed &&
            _currentGame?.gameStatus != GameStatus.completed) {
          _showGameOverDialog(game);
        }

        setState(() {
          _currentGame = game;
          if (_isLoading) _isLoading = false;
        });
      }
    });
  }

  Future<void> _loadOpponentProfile(String? opponentId) async {
    if (opponentId == null) return;

    if (opponentId.startsWith('bot_')) {
      final botType = _botService.getBotTypeFromId(opponentId);
      if (botType != null) {
        setState(() {
          _isBotMatch = true;
          // CHANGED: Pass the bot's local image path to the user model
          _opponentProfile = UserModel(
            userId: opponentId,
            username: _botService.getBotNameFromId(opponentId),
            profileImageUrl: _botService.getBotImagePath(botType),
          );
        });
      }
    } else {
      final profile = await _authService.getUserProfile(opponentId);
      if (mounted) {
        setState(() => _opponentProfile = profile);
      }
    }
  }

  void _startGameTimer(int startTimeMillis) {
    final startTime = DateTime.fromMillisecondsSinceEpoch(startTimeMillis);
    const gameDuration = Duration(minutes: 10); // Game duration
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

  void _initializePlayerStepCounter() {
    _healthService.initialize();
    _stepSubscription = _healthService.stepStream.listen(
      _onPlayerStep,
      onError: (error) => print("Step Stream Error: $error"),
    );
  }

  void _initializeBotStepGenerator() {
    _botStepTimer =
        Timer.periodic(const Duration(seconds: 1), _updateBotState);
  }

  void _onPlayerStep(String stepsStr) {
    if (_currentGame?.gameStatus == GameStatus.completed) return;
    final currentTotalSteps = int.tryParse(stepsStr);
    if (currentTotalSteps == null) return;

    if (_initialPlayerSteps == -1) _initialPlayerSteps = currentTotalSteps;

    final stepsThisGame = currentTotalSteps - _initialPlayerSteps;

    final currentStepsInDb =
        _isUserPlayer1 ? _currentGame?.step1Count : _currentGame?.step2Count;

    if (stepsThisGame >= 0 && stepsThisGame != currentStepsInDb) {
      final multiplier =
          _isUserPlayer1 ? _currentGame!.multiplier1 : _currentGame!.multiplier2;
      final newScore = (stepsThisGame * multiplier).round();

      if (_isUserPlayer1) {
        _gameService.updateGame(widget.gameId, {
          'step1_count': stepsThisGame,
          'player1_score': newScore,
        });
      } else {
        _gameService.updateGame(widget.gameId, {
          'step2_count': stepsThisGame,
          'player2_score': newScore,
        });
      }
    }
  }

  void _updateBotState(Timer timer) {
    if (!_isBotMatch ||
        _currentGame == null ||
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

  void _endGame({bool isKO = false}) {
    if (_currentGame == null ||
        _currentGame!.gameStatus == GameStatus.completed) return;

    int p1 = _currentGame!.player1Score;
    int p2 = _currentGame!.player2Score;
    GameResult result;
    String? winnerId;

    if (isKO) {
      result = GameResult.KO;
      winnerId = p1 > p2 ? _currentGame!.player1Id : _currentGame!.player2Id;
    } else {
      if ((p1 - p2).abs() <= 50) { // Draw Logic
        result = GameResult.draw;
      } else {
        result = GameResult.win;
        winnerId = p1 > p2 ? _currentGame!.player1Id : _currentGame!.player2Id;
      }
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

  void _applyMultiplier(double multiplier) {
    if (_currentGame == null ||
        _currentGame!.gameStatus == GameStatus.completed) return;

    setState(() {
      _selectedMultiplier = multiplier;
    });

    final String multiplierField =
        _isUserPlayer1 ? 'multiplier1' : 'multiplier2';
    _gameService.updateGame(widget.gameId, {multiplierField: multiplier});
  }

  Future<bool> _onWillPop() async {
    if (_currentGame?.gameStatus == GameStatus.ongoing) {
      final shouldLeave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2a2a2a),
          title: const Text('Leave Battle?',
              style: TextStyle(color: Colors.white)),
          content: const Text(
              'If you leave now, you will lose the battle. Are you sure?',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child:
                  const Text('Stay', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Leave',
                  style: TextStyle(color: Color(0xFFE53935))),
            ),
          ],
        ),
      );

      if (shouldLeave ?? false) {
        await _forfeitGame();
        return true;
      }
      return false;
    }
    return true;
  }

  Future<void> _forfeitGame() async {
    if (_currentGame == null) return;
    final winnerId = _isUserPlayer1
        ? _currentGame!.player2Id
        : _currentGame!.player1Id;
    await _gameService.updateGame(widget.gameId, {
      'gameStatus': GameStatus.completed.name,
      'winner': winnerId,
      'result': GameResult.win.name,
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _currentGame == null || _opponentProfile == null) {
      return const Scaffold(
          backgroundColor: Color(0xFF1E1E1E),
          body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFFC107))));
    }

    final player1 = _isUserPlayer1 ? widget.user : _opponentProfile!;
    final player2 = _isUserPlayer1 ? _opponentProfile! : widget.user;

    final p1Score = _currentGame!.player1Score;
    final p2Score = _currentGame!.player2Score;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        body: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTimer(),
                _buildPlayerStats(player1, player2, p1Score, p2Score),
                _buildBattleBar(p1Score, p2Score),
                _buildMultiplierSection(),
              ],
            ),
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

  Widget _buildPlayerStats(
      UserModel player1, UserModel player2, int p1Score, int p2Score) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildPlayerCard(
          player1.username ?? 'Player 1',
          p1Score,
          player1.profileImageUrl,
          _currentGame!.multiplier1,
        ),
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
        _buildPlayerCard(
          player2.username ?? 'Player 2',
          p2Score,
          player2.profileImageUrl,
          _currentGame!.multiplier2,
        ),
      ],
    );
  }

Widget _buildPlayerCard(
    String name, int score, String? imageUrl, double multiplier) {
  return Expanded(
    child: Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey.shade800,
              child: imageUrl == null
                  ? const Icon(Icons.person, size: 45, color: Colors.white70)
                  : ClipOval(
                      child: imageUrl.startsWith('assets/')
                          ? Image.asset(
                              imageUrl,
                              fit: BoxFit.contain,
                              width: 120, 
                              height: 120, 
                            )
                          : Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: 120,
                              height: 120,
                              loadingBuilder: (context, child, progress) =>
                                  progress == null
                                      ? child
                                      : const CircularProgressIndicator(),
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.person, size: 45, color: Colors.white70),
                            ),
                    ),
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
          score.toString(),
          style: const TextStyle(
              color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        const Text('Score',
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

  Widget _buildBattleBar(int p1Score, int p2Score) {
    final userIsPlayer1 = widget.user.userId == _currentGame?.player1Id;
    final diff = userIsPlayer1 ? (p1Score - p2Score) : (p2Score - p1Score);

    String statusText;
    Color statusColor;
    if (diff.abs() <= 50) {
      statusText = 'Even Match';
      statusColor = Colors.white;
    } else {
      statusText = '${diff > 0 ? "Ahead" : "Behind"} by ${diff.abs()}';
      statusColor = diff > 0 ? const Color(0xFF69F0AE) : Colors.yellow.shade700;
    }

    // Normalize the difference for the UI. Range: -1000 to +1000 => 0.0 to 1.0
    double normalizedValue = (diff.clamp(-1000, 1000) + 1000) / 2000;

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
            height: 50, // Compact height
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. The main gradient bar
                Container(
                  height: 25,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF42A5F5), // Your color
                        Color(0xFF373737), // Dark middle
                        Color(0xFF373737), // Dark middle
                        Color(0xFFEF5350), // Opponent's color
                      ],
                      stops: [0.0, 0.48, 0.52, 1.0], // Symmetrical stops
                    ),
                  ),
                ),

                // 2. Milestone markers (500 steps)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: barWidth * 0.25),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(width: 2, height: 15, color: Colors.white30),
                      Container(width: 2, height: 15, color: Colors.white30),
                    ],
                  ),
                ),
                
                // 3. KO markers (1000 steps)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(width: 2, height: 25, color: Colors.white60),
                    Container(width: 2, height: 25, color: Colors.white60),
                  ],
                ),

                // 4. The animated stopper
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  left: (barWidth - 16) * normalizedValue,
                  top: 25, // Position below the bar
                  child: const Icon(Icons.arrow_drop_up, color: Color(0xFFFFC107), size: 24),
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
              Text('Your KO', style: TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.bold)),
              Text('Draw', style: TextStyle(color: Colors.white70)),
              Text("Opponent's KO", style: TextStyle(color: Color(0xFFEF5350), fontWeight: FontWeight.bold)),
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
              _buildMultiplierButton('1.5X', 1.5),
              Container(width: 1, color: Colors.white30),
              _buildMultiplierButton('2X', 2.0),
              Container(width: 1, color: Colors.white30),
              _buildMultiplierButton('3X', 3.0),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildMultiplierButton(String text, double multiplier) {
    final bool isActive = _selectedMultiplier == multiplier;
    return Expanded(
      child: GestureDetector(
        onTap: () => _applyMultiplier(multiplier),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFFC107) : Colors.transparent,
            borderRadius: text == '1.5X'
                ? const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    bottomLeft: Radius.circular(11))
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
      ),
    );
  }
}