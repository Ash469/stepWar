import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/bot_service.dart';
import '../services/game_service.dart';
import '../services/active_battle_service.dart';
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
    _selectedBot = _botService.selectRandomBot();
    final int selectedBotIndex = _allBots.indexOf(_selectedBot);
    final String selectedBotId = _botService.getBotId(_selectedBot);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    _pageController.animateToPage(
      _allBots.length * 10 + selectedBotIndex,
      duration: const Duration(seconds: 5),
      curve: Curves.easeOutCubic,
    );
    
    await Future.delayed(const Duration(seconds: 6));
    if (!mounted) return;

    setState(() {
      _selectionComplete = true;
      final botName = _botService.getBotNameFromId(selectedBotId);
      _statusText = '$botName Selected!';
    });

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() {
      _statusText = 'Starting Battle...';
    });

    try {
      final gameId = await _gameService.createBotGame(
        widget.user,
        botId: selectedBotId
      );
      
      context.read<ActiveBattleService>().startBattle(gameId, widget.user);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const BattleScreen(),
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
          children: [
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Text(
                _statusText,
                key: ValueKey<String>(_statusText),
                style: TextStyle(
                    color: _selectionComplete ? const Color(0xFFFFC107) : Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 220,
              child: PageView.builder(
                controller: _pageController,
                itemBuilder: (context, index) {
                  final botType = _allBots[index % _allBots.length];
                  return _buildBotCard(botType);
                },
              ),
            ),
            const Spacer(flex: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _buildBattleInfo(),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
  
 Widget _buildBattleInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.grey.shade800)
      ),
      child: Column(
        children: [
          // --- Multiplier Section ---
          const Row(
            children: [
              Icon(Icons.flash_on, color: Color(0xFFFFC107), size: 20),
              SizedBox(width: 8),
              Text('Score Boosts', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Purchase multipliers during battle to skyrocket your score!',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMultiplierTag('1.5X'),
              _buildMultiplierTag('2X'),
              _buildMultiplierTag('3X'),
            ],
          ),
          const Divider(color: Colors.white24, height: 32),
          // --- Rewards Section ---
          const Row(
            children: [
              Icon(Icons.military_tech, color: Color(0xFFFFC107), size: 20),
              SizedBox(width: 8),
              Text('Coin Rewards', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('👑 K.O. Victory', 'Your Score + 5000 Coins'),
          const SizedBox(height: 12),
          _buildInfoRow('🏆 Win', 'Your Score + 2000 Coins'),
          const SizedBox(height: 12),
          _buildInfoRow('🤝 Draw', 'Your Score + 1000 Coins'),
        ],
      ),
    );
  }

  Widget _buildMultiplierTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade700)
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildInfoRow(String title, String subtitle) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const Spacer(),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
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
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFFFFC107).withOpacity(0.5),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Image.asset(
            botImagePath,
            height: 80,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.smart_toy, size: 60, color: Colors.white70),
          ),
          Text(
            botName,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}