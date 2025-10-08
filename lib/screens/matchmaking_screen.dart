import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/active_battle_service.dart';
import '../services/game_service.dart';
import 'battle_screen.dart';
import 'bot_selection_screen.dart'; // --- NEW: Import BotSelectionScreen ---

class MatchmakingScreen extends StatefulWidget {
  final UserModel user;
  const MatchmakingScreen({super.key, required this.user});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  final GameService _gameService = GameService();
  final DatabaseReference _poolRef =
      FirebaseDatabase.instance.ref('matchmakingPool');
  StreamSubscription? _poolListener;
  StreamSubscription? _selfListener;
  Timer? _countdownTimer; // Renamed for clarity

  String _statusText = "Searching for an opponent...";
  bool _isSearching = true;

  // --- NEW: State for the countdown timer ---
  Duration _timeLeft = const Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _startMatchmaking();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _poolListener?.cancel();
    _selfListener?.cancel();
    if (_isSearching) {
      _leavePool();
    }
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return twoDigits(duration.inSeconds.remainder(60));
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

    // --- MODIFIED: Create a periodic timer that updates the UI ---
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_timeLeft.inSeconds > 0) {
        setState(() {
          _timeLeft -= const Duration(seconds: 1);
        });
      } else {
        // When timer hits zero, stop it and trigger the timeout logic
        timer.cancel();
        _onTimeout();
      }
    });

    _poolListener = _poolRef.onValue.listen(_checkForOpponent);
    _selfListener = userNode.onValue.listen(_onSelfStatusChanged);
  }

  Future<void> _checkForOpponent(DatabaseEvent event) async {
    if (!_isSearching || !mounted) return;
    final data = event.snapshot.value as Map?;
    if (data == null || data.length < 2) return;

    final waitingPlayers = data.values
        .where((player) =>
            player is Map &&
            player['status'] == 'waiting' &&
            player['uid'] != widget.user.userId)
        .toList();

    if (waitingPlayers.isEmpty) return;

    waitingPlayers.sort((a, b) => a['entryTime'].compareTo(b['entryTime']));
    final opponent = waitingPlayers.first;
    final myEntryTime = data[widget.user.userId]?['entryTime'] ?? 9999999999999;

    if (myEntryTime < opponent['entryTime']) {
      await _tryToMatch(opponent['uid']);
    }
  }

  Future<void> _tryToMatch(String opponentId) async {
    _isSearching = false;
    _poolListener?.cancel();
    _countdownTimer?.cancel();

    final transactionResult = await _poolRef.runTransaction((Object? data) {
      final pool = data as Map<String, dynamic>?;
      if (pool == null) return Transaction.abort();

      final me = pool[widget.user.userId];
      final opponent = pool[opponentId];

      if (me?['status'] != 'waiting' || opponent?['status'] != 'waiting') {
        return Transaction.abort();
      }

      me['status'] = 'matched';
      opponent['status'] = 'matched';
      return Transaction.success(pool);
    });

    if (transactionResult.committed) {
      setState(() => _statusText = "Opponent found! Creating battle...");
      final gameId =
          await _gameService.createPvpBattle(widget.user.userId, opponentId);
      await _poolRef.child(widget.user.userId).update({'gameId': gameId});
      await _poolRef.child(opponentId).update({'gameId': gameId});
    } else {
      _isSearching = true;
      _poolListener = _poolRef.onValue.listen(_checkForOpponent);
    }
  }

  void _onSelfStatusChanged(DatabaseEvent event) {
    if (!mounted) return;
    final selfData = event.snapshot.value as Map?;
    if (selfData?['status'] == 'matched' && selfData?['gameId'] != null) {
      _navigateToBattle(selfData!['gameId']);
    }
  }

  Future<void> _navigateToBattle(String gameId) async {
    _isSearching = false;
    _countdownTimer?.cancel();
    _poolListener?.cancel();
    _selfListener?.cancel();

    if (mounted) {
      context.read<ActiveBattleService>().startBattle(gameId, widget.user);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const BattleScreen()),
      );
    }
    _leavePool();
  }

  Future<void> _onTimeout() async {
    if (!_isSearching || !mounted) return;

    setState(() => _statusText = "No opponents found. Finding a bot...");
    _isSearching = false;
    await _leavePool();

    // --- MODIFIED: Navigate to BotSelectionScreen instead of creating the game directly ---
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BotSelectionScreen(user: widget.user),
        ),
      );
    }
  }
  
  Future<void> _leavePool() async {
    // Cancel the onDisconnect handler before manually removing the node
    await _poolRef.child(widget.user.userId).onDisconnect().cancel();
    await _poolRef.child(widget.user.userId).remove();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _isSearching = false;
        await _leavePool();
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
              // --- NEW: Stack to overlay the timer on the progress indicator ---
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: _timeLeft.inSeconds / 15.0, // Show progress
                      color: const Color(0xFFFFC107),
                      backgroundColor: Colors.grey.shade800,
                      strokeWidth: 6,
                    ),
                  ),
                  Text(
                    _formatDuration(_timeLeft),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                ],
              ),
              const SizedBox(height: 32),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _statusText,
                  key: ValueKey<String>(_statusText),
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                ),
              ),
              const SizedBox(height: 80),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel Search',
                  style: TextStyle(color: Colors.redAccent, fontSize: 16),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}