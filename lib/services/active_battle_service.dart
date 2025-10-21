import 'dart:async';
import 'package:flutter/material.dart';
import '../models/battle_RB.dart';
import '../models/user_model.dart';
import 'game_service.dart';
import 'bot_service.dart';
import 'step_counting.dart';

class ActiveBattleService with ChangeNotifier {
  final _controller = StreamController<void>.broadcast();
  String? _gameId;
  final GameService _gameService = GameService();
  final BotService _botService = BotService();
  final HealthService _healthService = HealthService();
  Game? _currentGame;
  Timer? _botStepTimer;
  Timer? _gameTimer;
  StreamSubscription? _gameSubscription;
  StreamSubscription? _stepSubscription;
  bool _isGameOver = false;
  int _initialPlayerSteps = -1;
  Duration _timeLeft = Duration.zero;
  Game? get currentGame => _currentGame;
  Duration get timeLeft => _timeLeft;
  bool get isBattleActive => _gameId != null && !_isGameOver;
  bool _isActivatingMultiplier = false;
  bool get isActivatingMultiplier => _isActivatingMultiplier;
  Map<String, dynamic>? _finalBattleState; 
  Map<String, dynamic>? get finalBattleState => _finalBattleState;
  Stream<void> get stream => _controller.stream;
  bool get isWaitingForFriend => currentGame?.gameStatus == GameStatus.waiting;
  bool _isEndingBattle = false;
  bool get isEndingBattle => _isEndingBattle;


  Future<void> startBattle(String gameId, UserModel user) async {
    if (isBattleActive) {
      print("Warning: Tried to start a battle while one is already active.");
      return;
    }
    _cleanup();
    _gameId = gameId;
    _isGameOver = false;
    _initialPlayerSteps = -1;
    _gameSubscription = _gameService.getGameStream(gameId).listen((game) {
      if (game == null) return;
      _currentGame = game;
      if (game.startTime != null && _gameTimer == null) {
        _startGameTimer(game.startTime!);
      }
      final isBotMatch = (game.player2Id?.startsWith('bot_') ?? false);
      if (isBotMatch && _botStepTimer == null) {
        _initializeBotStepGenerator();
      }
      final koDifference = 200; 
      if (!_isGameOver &&
          (game.player1Score - game.player2Score).abs() >= koDifference) {
        endBattle();
      }
      notifyListeners();
    });
    _healthService.initialize();
    _stepSubscription = _healthService.stepStream.listen((stepsStr) {
      _onPlayerStep(stepsStr, user.userId);
    });
    notifyListeners();
  }

  void _onPlayerStep(String stepsStr, String userId) {
    if (_currentGame == null || _isGameOver) return;

    final currentTotalSteps = int.tryParse(stepsStr);
    if (currentTotalSteps == null) return;

    if (_initialPlayerSteps == -1) {
      _initialPlayerSteps = currentTotalSteps;
    }

    int stepsThisGame = currentTotalSteps - _initialPlayerSteps;
    
    if (stepsThisGame < 0) {
      print("Pedometer reset detected! Recalibrating initial steps.");
      _initialPlayerSteps = currentTotalSteps;
      stepsThisGame = 0;
    }
    final isUserPlayer1 = _currentGame!.player1Id == userId;
    final multiplier =
        isUserPlayer1 ? _currentGame!.multiplier1 : _currentGame!.multiplier2;
    final newScore = (stepsThisGame * multiplier).round();
    
    final updateData = isUserPlayer1
        ? {'step1Count': stepsThisGame, 'player1Score': newScore}
        : {'step2Count': stepsThisGame, 'player2Score': newScore};

    _gameService.updateGame(_currentGame!.gameId, updateData);
  }

  void _startGameTimer(int startTimeMillis) {
    final startTime = DateTime.fromMillisecondsSinceEpoch(startTimeMillis);
    const gameDuration = Duration(minutes: 10);
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed >= gameDuration) {
        _timeLeft = Duration.zero;
        endBattle();
      } else {
        _timeLeft = gameDuration - elapsed;
      }
      notifyListeners();
    });
  }

  void _initializeBotStepGenerator() {
    _botStepTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isGameOver && _currentGame != null) {
        final botId = _currentGame!.player2Id!;
        final botType = _botService.getBotTypeFromId(botId);
        if (botType != null) {
          final generatedSteps =
              _botService.generateStepsForOneSecond(botType) * 2;
          final newBotSteps = (_currentGame!.step2Count) + generatedSteps;
          final newBotScore = (newBotSteps * _currentGame!.multiplier2).round();
          _gameService.updateGame(_currentGame!.gameId, {
            'step2Count': newBotSteps,
            'player2Score': newBotScore,
          });
        }
      }
    });
  }

  Future<void> endBattle() async {
    if (_isGameOver || _currentGame == null || _isEndingBattle) return;
    _isEndingBattle = true;
    _isGameOver = true;
    notifyListeners();

    try {
      _finalBattleState = await _gameService.endBattle(_currentGame!.gameId);
      print("Battle ended with state: $_finalBattleState");
    } catch (e) {
      print("Error ending battle from service: $e");
      _isGameOver = false; 
    } finally {_isEndingBattle = false;}
     if (_finalBattleState != null) {
        notifyListeners();
        _controller.add(null);
    }
  }

  void dismissBattleResults() {
    _finalBattleState = null;
    _cleanup();
  }

  void _cleanup() {
    _gameSubscription?.cancel();
    _stepSubscription?.cancel();
    _botStepTimer?.cancel();
    _gameTimer?.cancel();
    _gameSubscription = null;
    _stepSubscription = null;
    _botStepTimer = null;
    _gameTimer = null;
    _gameId = null;
    _currentGame = null;
    _isGameOver = false;
    _timeLeft = Duration.zero;
    _initialPlayerSteps = -1;
    notifyListeners();
  }

  Future<void> activateMultiplier(String multiplierType, String userId) async {
    if (_isActivatingMultiplier || _currentGame == null) return;
    _isActivatingMultiplier = true;
    notifyListeners(); 

    try {
      await _gameService.useMultiplier(
        gameId: _currentGame!.gameId,
        userId: userId,
        multiplierType: multiplierType,
      );
    } catch (e) {
      rethrow;
    } finally {
      _isActivatingMultiplier = false;
      notifyListeners();
    }
  }


  Future<void> cancelFriendBattle() async {
    if (_gameId == null) return;
    try {
      await _gameService.cancelFriendGame(_gameId!);
    } catch (e) {
      print("Error cancelling battle: $e");
    } finally {
      _cleanup();
    }
  }
}

