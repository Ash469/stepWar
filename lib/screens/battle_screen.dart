import 'dart:async';
import 'package:flutter/material.dart';
import '../models/battle_RB.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/game_service.dart';
import '../services/bot_service.dart';
import '../services/step_counting.dart';

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
  bool _isActivatingMultiplier = false;
  Game? _currentGame;
  UserModel? _opponentProfile;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isUserPlayer1 = false;
  bool _isBotMatch = false;
  int _initialPlayerSteps = -1;
  Duration _timeLeft = const Duration(minutes: 10);
  bool _isGameOver = false;

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
      if (!mounted) return;

      if (game == null && !_isLoading) {
        return;
      }

      final isFirstLoad = _currentGame == null;
      if (isFirstLoad && game != null) {
        _isUserPlayer1 = widget.user.userId == game.player1Id;
        final opponentId = _isUserPlayer1 ? game.player2Id : game.player1Id;
        await _loadOpponentProfile(opponentId);
        if (game.startTime != null) {
          _startGameTimer(game.startTime!);
        }
        if (_isBotMatch && _botStepTimer == null) {
          _initializeBotStepGenerator();
        }
      }
      // Check for KO condition
      if (!_isGameOver &&
          game != null &&
          game.gameStatus == GameStatus.ongoing) {
        final p1Score = game.player1Score;
        final p2Score = game.player2Score;
        if ((p1Score - p2Score).abs() >= 100) {
          // This will now only be called once.
          _endGame();
        }
      }
      setState(() {
        _currentGame = game;
        if (_isLoading) _isLoading = false;
        _errorMessage = null;
      });
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Could not load battle data. Please try again.";
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
          _opponentProfile = UserModel(
            userId: opponentId,
            username: _botService.getBotNameFromId(opponentId),
            profileImageUrl: _botService.getBotImagePath(botType),
          );
        });
      }
    } else {
      final profile = await _authService.getUserProfile(opponentId);
      if (mounted) setState(() => _opponentProfile = profile);
    }
  }

  void _startGameTimer(int startTimeMillis) {
    final startTime = DateTime.fromMillisecondsSinceEpoch(startTimeMillis);
    const gameDuration = Duration(minutes: 10);
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
    _botStepTimer = Timer.periodic(const Duration(seconds: 2), _updateBotState);
  }

  void _onPlayerStep(String stepsStr) {
    if (_currentGame?.gameStatus != GameStatus.ongoing) return;
    final currentTotalSteps = int.tryParse(stepsStr);
    if (currentTotalSteps == null) return;
    if (_initialPlayerSteps == -1) _initialPlayerSteps = currentTotalSteps;
    final stepsThisGame = currentTotalSteps - _initialPlayerSteps;
    final currentStepsInDb =
        _isUserPlayer1 ? _currentGame?.step1Count : _currentGame?.step2Count;
    if (stepsThisGame >= 0 && stepsThisGame != currentStepsInDb) {
      final multiplier = _isUserPlayer1
          ? _currentGame!.multiplier1
          : _currentGame!.multiplier2;
      final newScore = (stepsThisGame * multiplier).round();
      final updateData = _isUserPlayer1
          ? {'step1Count': stepsThisGame, 'player1Score': newScore}
          : {'step2Count': stepsThisGame, 'player2Score': newScore};
      _gameService.updateGame(widget.gameId, updateData);
    }
  }

  void _updateBotState(Timer timer) {
    if (!_isBotMatch ||
        _currentGame == null ||
        _currentGame?.gameStatus != GameStatus.ongoing) return;

    final botId = _currentGame!.player2Id!;
    final botType = _botService.getBotTypeFromId(botId);
    if (botType != null) {
      final generatedSteps = _botService.generateStepsForOneSecond(botType) * 2;
      final newBotSteps = (_currentGame!.step2Count) + generatedSteps;
      final newBotScore = (newBotSteps * _currentGame!.multiplier2).round();

      _gameService.updateGame(widget.gameId, {
        'step2Count': newBotSteps,
        'player2Score': newBotScore,
      });
    }
  }

  Future<void> _endGame() async {
    if (_isGameOver) return;
    _isGameOver = true;
    if (_currentGame == null ||
        _currentGame!.gameStatus == GameStatus.completed) return;
    setState(() {
      _currentGame = _currentGame!.copyWith(gameStatus: GameStatus.completed);
    });
    try {
      final finalState = await _gameService.endBattle(widget.gameId);
      _showGameOverDialog(finalState);
    } catch (e) {
      print("Error ending game via backend: $e");
      _showGameOverDialog(null);
    }
  }

  void _showGameOverDialog(Map<String, dynamic>? finalState) {
    if (!mounted) return;
    String title;
    Widget content;
    if (finalState == null) {
      title = "Game Over";
      content = const Text(
          "Error saving results. Please check your battle history later.",
          style: TextStyle(color: Colors.white70));
    } else {
      final winnerId = finalState['finalState']?['winnerId'];
      final result = finalState['finalState']?['result'];
      final rewards = finalState['finalState']?['rewards'];
      final int coinsWon = rewards?['coins'] ?? 0;
      final Map<String, dynamic>? itemWon = rewards?['item'];
      if (result == "DRAW") {
        title = "It's a Draw!";
        content = Text("You earned $coinsWon coins for your effort.",
            style: const TextStyle(color: Colors.white70));
      } else if (winnerId == widget.user.userId) {
        title = "Congratulations, You Won!";
        if (itemWon != null) {
          content = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("You earned $coinsWon coins and discovered a new item!",
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              Text(itemWon['name'] ?? 'Unknown Item',
                  style: const TextStyle(
                      color: Color(0xFFFFC107),
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              Text(itemWon['tier'] ?? '',
                  style: const TextStyle(
                      color: Colors.white70, fontStyle: FontStyle.italic)),
            ],
          );
        } else {
          final message = rewards?['message'] ?? 'Better luck next time.';
          content = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("You earned a total of $coinsWon coins!",
                  style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 8),
              Text(message, style: const TextStyle(color: Colors.grey)),
            ],
          );
        }
      } else {
        title = "You Lost!";
        content = Text("You earned $coinsWon coins. Better luck next time.",
            style: const TextStyle(color: Colors.white70));
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: content,
        actions: [
          TextButton(
            child: const Text('Go to Home',
                style: TextStyle(color: Color(0xFFFFC107))),
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ],
      ),
    );
  }

  Future<void> _activateMultiplier(String multiplierType) async {
    if (_isActivatingMultiplier) return;
    setState(() {
      _isActivatingMultiplier = true;
    });
    try {
      await _gameService.useMultiplier(
        gameId: widget.gameId,
        userId: widget.user.userId,
        multiplierType: multiplierType,
      );
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
    } finally {
      if (mounted) {
        setState(() {
          _isActivatingMultiplier = false;
        });
      }
    }
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
              'If you leave now, it will count as a loss. Are you sure?',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Stay',
                    style: TextStyle(color: Colors.white70))),
            TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Leave',
                    style: TextStyle(color: Color(0xFFE53935)))),
          ],
        ),
      );
      if (shouldLeave ?? false) {
        await _endGame();
        return true;
      }
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          backgroundColor: Color(0xFF1E1E1E),
          body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFFC107))));
    }
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        body: Center(
            child: Text(_errorMessage!,
                style: const TextStyle(color: Colors.red))),
      );
    }
    if (_currentGame == null || _opponentProfile == null) {
      return const Scaffold(
          backgroundColor: Color(0xFF1E1E1E),
          body: Center(
              child: Text("Waiting for game data...",
                  style: TextStyle(color: Colors.white70))));
    }

    final player1 = _isUserPlayer1 ? widget.user : _opponentProfile!;
    final player2 = _isUserPlayer1 ? _opponentProfile! : widget.user;
    final p1Score = _currentGame!.player1Score;
    final p2Score = _currentGame!.player2Score;
    final p1Steps = _currentGame!.step1Count;
    final p2Steps = _currentGame!.step2Count;

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
                _buildPlayerStats(
                    player1, p1Score, p1Steps, player2, p2Score, p2Steps),
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
    final minutes =
        _timeLeft.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
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

  Widget _buildPlayerStats(UserModel player1, int p1Score, int p1Steps,
      UserModel player2, int p2Score, int p2Steps) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPlayerCard(player1.username ?? 'Player 1', p1Score, p1Steps,
            player1.profileImageUrl, _currentGame!.multiplier1),
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
            player2.profileImageUrl, _currentGame!.multiplier2),
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

  Widget _buildMultiplierSection() {
    return _isActivatingMultiplier
        ? const CircularProgressIndicator(color: Color(0xFFFFC107))
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMultiplierButton(
                  '1.5x', '1_5x', 15), // Pass both display text and API key
              _buildMultiplierButton('2x', '2x', 20),
              _buildMultiplierButton('3x', '3x', 30),
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
          Text(displayText, style: const TextStyle(color: Color(0xFFFFC107), fontSize: 20, fontWeight: FontWeight.bold)), // Use the display text here
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

extension GameCopyWith on Game {
  Game copyWith({GameStatus? gameStatus}) {
    return Game(
      gameId: gameId,
      player1Id: player1Id,
      player2Id: player2Id,
      step1Count: step1Count,
      step2Count: step2Count,
      multiplier1: multiplier1,
      multiplier2: multiplier2,
      player1Score: player1Score,
      player2Score: player2Score,
      gameStatus: gameStatus ?? this.gameStatus,
      result: result,
      winner: winner,
      startTime: startTime,
    );
  }
}
