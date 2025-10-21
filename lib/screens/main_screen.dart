import 'dart:async';
import 'package:flutter/material.dart';
import 'home_screen.dart' as app_screens;
import 'kingdom_screen.dart';
import 'profile_screen.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/active_battle_service.dart';
import '../services/auth_service.dart';
import 'bot_selection_screen.dart';
import 'matchmaking_screen.dart';
import 'waiting_for_friend_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 1;
  final List<Widget> _pages = [
    const KingdomScreen(),
    const app_screens.HomeScreen(),
    const ProfileScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  late final StreamSubscription _battleStateSubscription;
  @override
  void initState() {
    super.initState();
    final battleService = context.read<ActiveBattleService>();
    _battleStateSubscription = battleService.stream.listen((_) {
      if (battleService.finalBattleState != null) {
        _showGameOverDialog(battleService.finalBattleState!);
      }
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _battleStateSubscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      final battleService = context.read<ActiveBattleService>();
      if (battleService.isBattleActive && (battleService.timeLeft.isNegative || battleService.timeLeft.inSeconds == 0)) {
        battleService.endBattle();
      }
    }
  }

  void _showGameOverDialog(Map<String, dynamic> finalState) {
    final authService = context.read<AuthService>();
    final battleService = context.read<ActiveBattleService>();
    final currentUserId = authService.currentUser?.uid;

    final gameState = finalState['finalState'];
    if (gameState == null) return;

    final winnerId = gameState['winnerId'];
    final result = gameState['result'];
    final rewards = gameState['rewards'];
    final gameType = gameState['gameType']; // 'PVP', 'BOT', 'FRIEND'
    final bool isWinner = winnerId == currentUserId;
    final int coinsToShow;
    if (result == 'DRAW') {
      coinsToShow = rewards?['winnerCoins'] ?? 0;
    } else {
      coinsToShow = isWinner
          ? (rewards?['winnerCoins'] ?? 0)
          : (rewards?['loserCoins'] ?? 0);
    }
    final rewardItemToShow =
        rewards?['item'] != null && isWinner ? rewards!['item'] : null;
    final isKnockout = result == 'KO';

    String title;
    String subtitle;
    Color titleBorderColor;

    if (result == 'DRAW') {
      title = "It's a Draw!";
      subtitle = "You both fought well!";
      titleBorderColor = Colors.grey;
    } else if (winnerId == currentUserId) {
      if (isKnockout) {
        title = "Winner";
        subtitle = "You won this battle with a\nKnockout.";
        titleBorderColor = const Color(0xFFFFC107);
      } else {
        title = "Winner";
        subtitle = "You won this battle!";
        titleBorderColor = const Color(0xFFFFC107);
      }
    } else {
      title = "Defeat";
      subtitle = "Better luck next time!";
      titleBorderColor = Colors.red;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 300,
          decoration: BoxDecoration(
            color: const Color(0xFF1a1a1a),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2a2a2a),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(color: titleBorderColor, width: 3),
                    left: BorderSide(color: titleBorderColor, width: 3),
                    right: BorderSide(color: titleBorderColor, width: 3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '👑',
                      style: TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '👑',
                      style: TextStyle(fontSize: 20),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Your Rewards",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (winnerId == currentUserId && rewardItemToShow != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2a2a2a),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF404040),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9800),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.location_city,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rewardItemToShow['name'] ??
                                        'Mystery Reward',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    rewardItemToShow['tier'] ?? 'New reward',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2a2a2a),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF404040),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFC107),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.monetization_on,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$coinsToShow coins',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop(); 
                          battleService.dismissBattleResults();

                          if (!mounted) return;

                          final user = await authService.refreshUserProfile(currentUserId!);
                          if (user == null || !mounted) return;
                          
                          print("--- BATTLE ENDED --- Navigating based on Game Type: '$gameType'");

                          switch (gameType) {
                            case 'PVP':
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => MatchmakingScreen(user: user))
                              );
                              break;
                            case 'BOT':
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => MatchmakingScreen(user: user))
                              );
                              break;
                            case 'FRIEND':
                              // For FRIEND battles, just go back to the home screen.
                              break;
                            default:
                              print("--- WARNING --- Unknown gameType '$gameType' received. Defaulting to home screen.");
                              break;
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Battle Again',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Column(
          children: [
            Container(
              height: statusBarHeight,
              color: Colors.yellow.shade700,
            ),
            Expanded(
              child: Stack(
                children: [
                  _pages[_currentIndex],
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _buildBottomNavBar(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              activeImageAsset: 'assets/images/kingdom_active.png',
              inactiveImageAsset: 'assets/images/kingdom.png',
              label: 'Kingdom',
              index: 0,
            ),
            _buildNavItem(
              activeImageAsset: 'assets/images/home_active.png',
              inactiveImageAsset: 'assets/images/home.png',
              label: 'Home',
              index: 1,
            ),
            _buildNavItem(
              activeImageAsset: 'assets/images/profile_active.png',
              inactiveImageAsset: 'assets/images/profile.png',
              label: 'Profile',
              index: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required String activeImageAsset,
    required String inactiveImageAsset,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.translucent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color.fromARGB(181, 251, 193, 45)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              isSelected ? activeImageAsset : inactiveImageAsset,
              width: 28,
              height: 28,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontSize: 12,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

