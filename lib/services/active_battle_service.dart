import 'dart:async';
import 'package:flutter/material.dart';
import '../models/battle_rb.dart';
import '../models/user_model.dart';
import 'game_service.dart';
import 'bot_service.dart';
import 'step_counting.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
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
  DateTime _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration _syncInterval = const Duration(seconds: 5);

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
    int myScore =
        isUserPlayer1 ? _currentGame!.player1Score : _currentGame!.player2Score;
    int opponentScore =
        isUserPlayer1 ? _currentGame!.player2Score : _currentGame!.player1Score;

    bool battleActive = !_isGameOver && _gameId != null;
    print(
        "ActiveBattleService: Sending battle state to task - battleActive: $battleActive, myScore: $myScore, opponentScore: $opponentScore");
    FlutterForegroundTask.sendDataToTask({
      'battleActive': battleActive,
      'myScore': myScore,
      'opponentScore': opponentScore,
      'timeLeft': _formatDuration(_timeLeft),
    });
  }

  void _handleRemoteGameEnd(Game finishedGame) {
    if (_isGameOver) return;
    _isGameOver = true;
    _currentGame = finishedGame;
    _finalBattleState = {
      'finalState': {
        'gameType':
            finishedGame.player2Id?.startsWith('bot_') == true ? 'BOT' : 'PVP',
        'winnerId': finishedGame.winner,
        'result': finishedGame.result?.name.toUpperCase() ?? 'DRAW',
        'isKnockout': finishedGame.result == GameResult.KO,
        'player1Score': finishedGame.player1Score,
        'player2Score': finishedGame.player2Score,
        'rewards': {
          'winnerCoins': finishedGame.winnerCoins,
          'loserCoins': finishedGame.loserCoins,
          'item': finishedGame.wonItem
        }
      }
    };
    _botStepTimer?.cancel();
    _gameTimer?.cancel();
    notifyListeners();
    _controller.add(null);
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
    _lastSyncTime = DateTime.now();
    _gameSubscription = _gameService.getGameStream(gameId).listen((game) {
      if (_isGameOver) {
        _gameSubscription?.cancel();
        _gameSubscription = null;
        return;
      }
      if (game == null) return;
      if (game.gameStatus == GameStatus.completed) {
        _handleRemoteGameEnd(game);
        return;
      }
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
      // Check if the battle is over before doing anything
      if (_isGameOver) {
        _stepSubscription?.cancel();
        _stepSubscription = null;
        return;
      }
      _onPlayerStep(stepsStr, user.userId);
    });
    await Future.delayed(const Duration(milliseconds: 100));
    _sendBattleStateToTask();
    notifyListeners();
  }

  Future<void> forfeitBattle() async {
    print("ActiveBattleService: forfeitBattle called");
    if (_currentGame == null) return;
    if (_currentUser == null) return;
    if (_isEndingBattle) return;
    _isEndingBattle = true;
    _isGameOver = true;
    notifyListeners();
    int p1Score = _currentGame!.player1Score;
    int p2Score = _currentGame!.player2Score;
    try {
      if (_currentGame!.gameId.isEmpty) {
        throw Exception('Invalid game ID');
      }
      _finalBattleState = await _gameService.endBattle(
        _currentGame!.gameId,
        player1FinalScore: p1Score,
        player2FinalScore: p2Score,
      );
    } catch (e) {
      print("Error forfeiting battle from service: $e");
      String gameType = 'UNKNOWN';
      if (_currentGame != null) {
        if (_currentGame!.player2Id != null &&
            _currentGame!.player2Id!.startsWith('bot_')) {
          gameType = 'BOT';
        } else if (_currentGame!.player2Id != null) {
          gameType = 'PVP';
        }
      }
      _finalBattleState = {
        'finalState': {
          'winnerId': null,
          'result': 'ERROR',
          'gameType': gameType,
          'isKnockout': false,
          'rewards': {
            'winnerCoins': 0,
            'loserCoins': 0,
          }
        }
      };
    } finally {
      _isEndingBattle = false;
      notifyListeners();
    }
    _sendBattleStateToTask();
    if (_finalBattleState != null) {
      notifyListeners();
      _controller.add(null);
    } else {
      _cleanup();
      _gameId = null;
      _sendBattleStateToTask();
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
    if (isUserPlayer1) {
    }
    final now = DateTime.now();
    if (now.difference(_lastSyncTime) >= _syncInterval) {
      print("Syncing steps to DB: $stepsThisGame");
      final updateData = isUserPlayer1
          ? {'step1Count': stepsThisGame, 'player1Score': newScore}
          : {'step2Count': stepsThisGame, 'player2Score': newScore};
      _gameService.updateGame(_currentGame!.gameId, updateData);
      _lastSyncTime = now;
    }
  }

  void _startGameTimer(int startTimeMillis) {
    final startTime = DateTime.fromMillisecondsSinceEpoch(startTimeMillis);
    final battleMinutes = _remoteConfig.getInt('battle_time_minutes');
    final gameDuration = Duration(minutes: battleMinutes);
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isGameOver) {
        timer.cancel();
        return;
      }
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
      if (_isGameOver || _currentGame == null) {
        timer.cancel();
        return;
      }
      final botId = _currentGame!.player2Id!;
      final botType = _botService.getBotTypeFromId(botId);
      if (botType != null) {
        final generatedSteps = _botService.generateStepsForOneSecond(botType);
        final newBotSteps = (_currentGame!.step2Count) + generatedSteps;
        final newBotScore = (newBotSteps * _currentGame!.multiplier2).round();
        _gameService.updateGame(_currentGame!.gameId, {
          'step2Count': newBotSteps,
          'player2Score': newBotScore,
        });
      }
    });
  }

  Future<void> endBattle() async {
    if (_currentGame == null) return;
    if (_isEndingBattle) return;

    _isEndingBattle = true;
    _isGameOver = true;
    notifyListeners();

    int p1Score = _currentGame!.player1Score;
    int p2Score = _currentGame!.player2Score;

    try {
      if (_currentGame!.gameId.isEmpty) {
        throw Exception('Invalid game ID');
      }
      // This call returns the JSON you posted. We assign it directly.
      _finalBattleState = await _gameService.endBattle(
        _currentGame!.gameId,
        player1FinalScore: p1Score,
        player2FinalScore: p2Score,
      );
      print("Battle ended with state: $_finalBattleState");
    } catch (e) {
      String gameType = 'UNKNOWN';
      if (_currentGame != null) {
        if (_currentGame!.player2Id != null &&
            _currentGame!.player2Id!.startsWith('bot_')) {
          gameType = 'BOT';
        } else if (_currentGame!.player2Id != null) {
          gameType = 'PVP';
        }
      }
      _finalBattleState = {
        'finalState': {
          'winnerId': null,
          'result': 'ERROR',
          'gameType': gameType,
          'isKnockout': false,
          'rewards': {'winnerCoins': 0, 'loserCoins': 0}
        }
      };
    } finally {
      _isEndingBattle = false;
      notifyListeners();
    }
    _sendBattleStateToTask();
    if (_finalBattleState != null) {
      notifyListeners();
      _controller.add(null);
    } else {
      _cleanup();
      _gameId = null;
      _sendBattleStateToTask();
      notifyListeners();
      _controller.add(null);
    }
  }

  void dismissBattleResults() {
    _finalBattleState = null;
    _isGameOver = false;
    _cleanup();
  }

  void _cleanup() {
    print("ActiveBattleService: Cleaning up battle state");
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
    _isGameOver = false;
    print("ActiveBattleService: Sending battle state to task after cleanup");
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
