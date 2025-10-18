import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/active_battle_service.dart';
import '../services/game_service.dart';
import 'battle_screen.dart';
import 'bot_selection_screen.dart';
import '../widget/game_rules.dart';

class MatchmakingScreen extends StatefulWidget {
  final UserModel user;
  const MatchmakingScreen({super.key, required this.user});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen>
    with TickerProviderStateMixin {
  final GameService _gameService = GameService();
  final DatabaseReference _poolRef =
      FirebaseDatabase.instance.ref('matchmakingPool');
  StreamSubscription? _poolListener;
  StreamSubscription? _selfListener;
  Timer? _countdownTimer;

  String _statusText = "Searching for an opponent...";
  bool _isSearching = true;
  bool _isNavigating = false;
  Duration _timeLeft = const Duration(seconds: 10);

  bool _matchmakingTimedOut = false;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _startMatchmaking();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _glowAnimation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _poolListener?.cancel();
    _selfListener?.cancel();
    _glowController.dispose();
    if (_isSearching && !_isNavigating) {
      _leavePool();
    }
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return twoDigits(duration.inSeconds.remainder(60));
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _countdownTimer?.cancel();
        return;
      }
      if (_timeLeft.inSeconds <= 0) {
        _countdownTimer?.cancel();
        _onTimeout();
      } else if (mounted) {
        setState(() {
          _timeLeft = _timeLeft - const Duration(seconds: 1);
        });
      }
    });
  }

  Future<void> _startMatchmaking() async {
    final userNode = _poolRef.child(widget.user.userId);
    await userNode.set({
      'uid': widget.user.userId,
      'username': widget.user.username,
      'entryTime': ServerValue.timestamp,
      'status': 'waiting',
    });
    await userNode.onDisconnect().remove();

    _startTimer();

    _poolListener = _poolRef.onValue.listen(_checkForOpponent);
    _selfListener = userNode.onValue.listen(_onSelfStatusChanged);
  }

  void _onSelfStatusChanged(DatabaseEvent event) {
    // FIXED: Check _isNavigating instead of _isSearching to allow proper navigation
    if (!mounted || _isNavigating) return;

    final selfData = event.snapshot.value as Map?;

    // FIXED: Check if we're matched and have a gameId
    if (selfData != null &&
        selfData['status'] == 'matched' &&
        selfData['gameId'] != null) {
      _navigateToBattle(selfData['gameId']);
    }
  }

  Future<void> _checkForOpponent(DatabaseEvent event) async {
    if (!_isSearching || !mounted || _isNavigating) return;
    final data = event.snapshot.value as Map?;
    if (data == null || data.length < 2) return;

    final waitingPlayers = data.values
        .where((player) =>
            player is Map &&
            player['status'] == 'waiting' &&
            player['uid'] != widget.user.userId)
        .toList();

    if (waitingPlayers.isEmpty) return;

    final opponent = waitingPlayers.first;

    if (widget.user.userId.compareTo(opponent['uid']) < 0) {
      await _tryToMatch(opponent['uid']);
    }
  }

  Future<void> _tryToMatch(String opponentId) async {
    if (!_isSearching || _isNavigating) return;
    _isSearching = false;
    _poolListener?.cancel();

    final transactionResult = await _poolRef.runTransaction((Object? data) {
      if (data == null) {
        return Transaction.abort();
      }

      final pool = Map<String, dynamic>.from(data as Map);

      final meData = pool[widget.user.userId];
      final opponentData = pool[opponentId];

      if (meData == null ||
          opponentData == null ||
          meData is! Map ||
          opponentData is! Map) {
        return Transaction.abort();
      }

      final me = Map<String, dynamic>.from(meData);
      final opponent = Map<String, dynamic>.from(opponentData);

      if (me['status'] != 'waiting' || opponent['status'] != 'waiting') {
        return Transaction.abort();
      }

      me['status'] = 'matched';
      opponent['status'] = 'matched';

      pool[widget.user.userId] = me;
      pool[opponentId] = opponent;

      return Transaction.success(pool);
    });

    if (transactionResult.committed) {
      if (!mounted) return;

      setState(() => _statusText = "Opponent found! Creating battle...");

      // FIXED: Create game and update both nodes with gameId atomically
      try {
        final gameId =
            await _gameService.createPvpBattle(widget.user.userId, opponentId);

        // Update both players with gameId at the same time
        await Future.wait([
          _poolRef.child(widget.user.userId).update({'gameId': gameId}),
          _poolRef.child(opponentId).update({'gameId': gameId}),
        ]);

        // FIXED: Navigate immediately after updating
        await _navigateToBattle(gameId);
      } catch (e) {
        // If something fails, reset and try again
        if (mounted) {
          setState(() {
            _isSearching = true;
            _statusText = "Searching for an opponent...";
          });
          _poolListener = _poolRef.onValue.listen(_checkForOpponent);
        }
      }
    } else {
      _isSearching = true;
      if (mounted) {
        _poolListener = _poolRef.onValue.listen(_checkForOpponent);
      }
    }
  }

  Future<void> _navigateToBattle(String gameId) async {
    // FIXED: Use _isNavigating to prevent double navigation
    if (!mounted || _isNavigating) return;

    _isNavigating = true;
    _isSearching = false;
    _countdownTimer?.cancel();
    _poolListener?.cancel();
    _selfListener?.cancel();

    // FIXED: Add a small delay to ensure Firebase updates are processed
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      context.read<ActiveBattleService>().startBattle(gameId, widget.user);

      // FIXED: Use pushAndRemoveUntil to prevent back navigation issues
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BattleScreen()),
        (route) => route.isFirst, // Keep only the first route
      );
    }

    await _leavePool();
  }

  Future<void> _onTimeout() async {
    if (!mounted || !_isSearching || _isNavigating) return;

    _isSearching = false;
    _poolListener?.cancel();
    _selfListener?.cancel();
    await _leavePool();
    if (mounted) {
      setState(() {
        _statusText = "No opponent found. Play with a bot?";
        _matchmakingTimedOut = true;
      });
    }
  }

  Future<void> _onPlayWithBotPressed() async {
    if (!mounted || _isNavigating) return;

    _isNavigating = true;
    _isSearching = false;
    _countdownTimer?.cancel();
    _poolListener?.cancel();
    _selfListener?.cancel();
    await _leavePool();

    if (mounted) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BotSelectionScreen(user: widget.user),
        ),
      );
    }
  }

  Future<void> _leavePool() async {
    final userNode = _poolRef.child(widget.user.userId);
    await userNode.onDisconnect().cancel();
    try {
      await userNode.remove();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!_isNavigating) {
          _isSearching = false;
          await _leavePool();
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        appBar: AppBar(
          title: const Text('Online Battle'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_matchmakingTimedOut)
                const SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFC107),
                    backgroundColor: Color.fromARGB(255, 68, 68, 68),
                    strokeWidth: 6,
                  ),
                )
              else
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade800, width: 6),
                  ),
                  child: Icon(
                    Icons.person_off,
                    color: Colors.grey.shade400,
                    size: 40,
                  ),
                ),
              const SizedBox(height: 32),
              // --- ADDED: AnimatedSwitcher for status text ---
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _statusText,
                  key: ValueKey<String>(_statusText),
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                ),
              ),
              const SizedBox(height: 80),
              // --- MODIFIED: Button is no longer conditional ---
              AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  final glow = _glowAnimation.value;
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      // Only apply shadow if timeout has occurred
                      boxShadow: _matchmakingTimedOut
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFFC107)
                                    .withOpacity(0.7 * glow),
                                blurRadius: 10 + (glow * 10),
                                spreadRadius: 1 + (glow * 2),
                              )
                            ]
                          : null, // No glow before timeout
                    ),
                    child: child,
                  );
                },
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isNavigating
                      ? null
                      : _onPlayWithBotPressed, // Button press logic
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Play with Bot',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.red,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 50),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: GameRulesWidget(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}