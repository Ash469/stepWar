import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/battle_rb.dart';
import '../models/user_model.dart';
import '../services/game_service.dart';
import '../widget/game_rules.dart'; 
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
        _gameSubscription?.cancel();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const BattleScreen(),
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
        title: const Text('Friend Battle Lobby'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildPlayerCard(widget.user),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('VS', style: TextStyle(color: Colors.grey.shade600, fontSize: 28, fontWeight: FontWeight.bold)),
                ),
                _buildOpponentPlaceholder(),
              ],
            ),
            Column(
              children: [
                const Text(
                  'Share this ID with your friend',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 16),
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
                      Text(widget.gameId, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 3)),
                      IconButton(icon: const Icon(Icons.copy, color: Color(0xFFFFC107)), onPressed: _copyGameId),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const CircularProgressIndicator(color: Color(0xFFFFC107)),
                const SizedBox(height: 12),
                const Text('Waiting for opponent...', style: TextStyle(color: Colors.white70)),
              ],
            ),
            const GameRulesWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCard(UserModel user) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.grey.shade800,
            backgroundImage: user.profileImageUrl != null ? NetworkImage(user.profileImageUrl!) : null,
            child: user.profileImageUrl == null ? const Icon(Icons.person, size: 35, color: Colors.white70) : null,
          ),
          const SizedBox(height: 12),
          Text(user.username ?? 'You',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  Widget _buildOpponentPlaceholder() {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFF2a2a2a),
            child: Icon(Icons.person_search, size: 35, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Text('Waiting...',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}