import 'dart:async';
import 'package:flutter/material.dart';
import '../models/battle_rb.dart';
import '../models/user_model.dart';
import 'game_service.dart';
import 'bot_service.dart';
import 'step_counting.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart'; 
import 'package:firebase_remote_config/firebase_remote_config.dart';

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
  UserModel? _currentUser;
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;


String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }


  void _sendBattleStateToTask() {
    if (_currentGame == null || _currentUser == null) {
      FlutterForegroundTask.sendDataToTask({'battleActive': false});
      return;
    }

    bool isUserPlayer1 = _currentGame!.player1Id == _currentUser!.userId;
    int myScore = isUserPlayer1 ? _currentGame!.player1Score : _currentGame!.player2Score;
    int opponentScore = isUserPlayer1 ? _currentGame!.player2Score : _currentGame!.player1Score;

    FlutterForegroundTask.sendDataToTask({
      'battleActive': !_isGameOver && _gameId != null, 
      'myScore': myScore,
      'opponentScore': opponentScore,
      'timeLeft': _formatDuration(_timeLeft),
    });
  }

  Future<void> startBattle(String gameId, UserModel user) async {
    if (isBattleActive) {
      print("Warning: Tried to start a battle while one is already active.");
      return;
    }
    _cleanup();
    _gameId = gameId;
    _isGameOver = false;
    _currentUser = user;
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
      final koDifference = _remoteConfig.getInt('ko_diff');
      if (!_isGameOver &&
          (game.player1Score - game.player2Score).abs() >= koDifference) {
        endBattle();
      }
      _sendBattleStateToTask();
      notifyListeners();
    });
    _healthService.initialize();
    _stepSubscription = _healthService.stepStream.listen((stepsStr) {
      _onPlayerStep(stepsStr, user.userId);
    });
    await Future.delayed(const Duration(milliseconds: 100));
    _sendBattleStateToTask();
    notifyListeners();
  }

Future<void> forfeitBattle() async {
    // Validate all required data before proceeding
    if (_currentGame == null) {
      print("Cannot forfeit battle: No current game data");
      return;
    }
    
    if (_currentUser == null) {
      print("Cannot forfeit battle: No current user data");
      return;
    }
    
    // Prevent multiple simultaneous forfeit attempts
    if (_isEndingBattle) {
      print("Battle forfeit already in progress, skipping duplicate call");
      return;
    }
    
    _isEndingBattle = true;
    _isGameOver = true;
    notifyListeners();

    int p1Score = _currentGame!.player1Score;
    int p2Score = _currentGame!.player2Score;

    try {
      // Ensure we have a valid game ID
      if (_currentGame!.gameId.isEmpty) {
        throw Exception('Invalid game ID');
      }
      
      _finalBattleState = await _gameService.endBattle(
        _currentGame!.gameId,
        player1FinalScore: p1Score,
        player2FinalScore: p2Score,
      );
      print("Battle forfeited with final scores ($p1Score, $p2Score). State: $_finalBattleState");
    } catch (e) {
      print("Error forfeiting battle from service: $e");
      // Even if there's an error, we still want to clean up
      _finalBattleState = null;
    } finally {
      _isEndingBattle = false;
    }
    
    if (_finalBattleState != null) {
      notifyListeners();
      _controller.add(null);
    }
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
   final battleMinutes = _remoteConfig.getInt('battle_time_minutes');
    final gameDuration = Duration(minutes: battleMinutes);
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed >= gameDuration) {
        _timeLeft = Duration.zero;
        endBattle();
      } else {
        _timeLeft = gameDuration - elapsed;
        _sendBattleStateToTask();
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
    // Validate battle state before attempting to end
    if (_currentGame == null) {
      print("Cannot end battle: No current game data");
      return;
    }
    
    // Prevent multiple simultaneous end attempts
    if (_isEndingBattle) {
      print("Battle ending already in progress, skipping duplicate call");
      return;
    }
    
    _isEndingBattle = true;
    _isGameOver = true;
    notifyListeners();

    try {
      // Ensure we have a valid game ID
      if (_currentGame!.gameId.isEmpty) {
        throw Exception('Invalid game ID');
      }
      
      _finalBattleState = await _gameService.endBattle(_currentGame!.gameId);
      print("Battle ended with state: $_finalBattleState");
    } catch (e) {
      print("Error ending battle from service: $e");
      // Even if there's an error, we still want to clean up
      _finalBattleState = null;
    } finally {
      _isEndingBattle = false;
    }
     
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
    _timeLeft = Duration.zero;
    _initialPlayerSteps = -1;
    _sendBattleStateToTask();
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

