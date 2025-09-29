import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/battle_RB.dart';
import '../models/user_model.dart';
import '../services/game_service.dart';
import 'battle_screen.dart';

class WaitingForFriendScreen extends StatefulWidget {
  final String gameId;
  final UserModel user;

  const WaitingForFriendScreen(
      {super.key, required this.gameId, required this.user});

  @override
  State<WaitingForFriendScreen> createState() => _WaitingForFriendScreenState();
}

class _WaitingForFriendScreenState extends State<WaitingForFriendScreen> {
  final GameService _gameService = GameService();
  StreamSubscription? _gameSubscription;

  @override
  void initState() {
    super.initState();
    _listenForOpponent();
  }

  @override
  void dispose() {
    _gameSubscription?.cancel();
    super.dispose();
  }

  void _listenForOpponent() {
    _gameSubscription =
        _gameService.getGameStream(widget.gameId).listen((game) {
      if (game != null &&
          game.player2Id != null &&
          game.gameStatus == GameStatus.ongoing) {
        // Opponent joined, navigate to battle screen
        _gameSubscription?.cancel(); // Stop listening
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BattleScreen(gameId: widget.gameId, user: widget.user),
          ),
        );
      }
    });
  }

  void _copyGameId() {
    Clipboard.setData(ClipboardData(text: widget.gameId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Game ID copied to clipboard!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Waiting for Friend',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Share the Game ID with your friend to start the battle.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFF2a2a2a),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFC107)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        widget.gameId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Color(0xFFFFC107)),
                      onPressed: _copyGameId,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(color: Color(0xFFFFC107)),
              const SizedBox(height: 20),
              const Text(
                'Listening for opponent...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
