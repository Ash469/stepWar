import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/bot_service.dart';
import '../services/game_service.dart';
import '../widget/game_rules.dart';
import 'battle_screen.dart';

class BotSelectionScreen extends StatefulWidget {
  final UserModel user;
  const BotSelectionScreen({super.key, required this.user});

  @override
  State<BotSelectionScreen> createState() => _BotSelectionScreenState();
}

class _BotSelectionScreenState extends State<BotSelectionScreen> {
  final BotService _botService = BotService();
  final GameService _gameService = GameService();
  final PageController _pageController = PageController(viewportFraction: 0.6);
  final List<BotType> _allBots = BotType.values;
  
  late BotType _selectedBot;
  bool _selectionComplete = false;
  String _statusText = "Finding Your Opponent...";

  @override
  void initState() {
    super.initState();
    _startBotSelection();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _startBotSelection() async {
    // 1. Select the bot instantly for the backend
    _selectedBot = _botService.selectRandomBot();
    final int selectedBotIndex = _allBots.indexOf(_selectedBot);

    // 2. Animate the selection for the user
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    _pageController.animateToPage(
      _allBots.length * 10 + selectedBotIndex,
      // CHANGED: Increased duration from 3 to 5 seconds for a slower scroll
      duration: const Duration(seconds: 5),
      curve: Curves.easeOutCubic,
    );

    // 3. Wait for animation to finish, then create game and navigate
    // CHANGED: Increased delay from 4 to 6 seconds to match the longer animation
    await Future.delayed(const Duration(seconds: 6));
    if (!mounted) return;

    setState(() {
      _selectionComplete = true;
      final botName = _botService.getBotNameFromId(_botService.getBotId(_selectedBot));
      _statusText = '$botName Selected!';
    });
    
    // Brief pause to show the selected bot
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    
    setState(() {
      _statusText = 'Starting Battle...';
    });

    try {
      final gameId = await _gameService.createBotGame(widget.user);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BattleScreen(gameId: gameId, user: widget.user),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start game: $e')));
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text('Online Battle'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Status Text
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Text(
                _statusText,
                key: ValueKey<String>(_statusText), // Important for AnimatedSwitcher
                style: TextStyle(
                  color: _selectionComplete ? const Color(0xFFFFC107) : Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
            
            // Middle: Bot Selector
            SizedBox(
              height: 220, // Increased height for larger cards
              child: PageView.builder(
                controller: _pageController,
                itemBuilder: (context, index) {
                  final botType = _allBots[index % _allBots.length];
                  return _buildBotCard(botType);
                },
              ),
            ),

            // Bottom: Rules
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: GameRulesWidget(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotCard(BotType botType) {
    final botName = _botService.getBotNameFromId(_botService.getBotId(botType));
    final botImagePath = _botService.getBotImagePath(botType);
    final isSelected = _selectionComplete && botType == _selectedBot;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFFFFC107) : Colors.grey.shade800,
          width: isSelected ? 3 : 1,
        ),
        boxShadow: isSelected ? [
          BoxShadow(
            color: const Color(0xFFFFC107).withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 2,
          )
        ] : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Image.asset(
            botImagePath,
            height: 80,
            // Add a fallback error widget
            errorBuilder: (context, error, stackTrace) => 
              const Icon(Icons.smart_toy, size: 60, color: Colors.white70),
          ),
          Text(
            botName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600
            )
          ),
        ],
      ),
    );
  }
}