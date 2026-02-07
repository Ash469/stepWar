// ignore_for_file: unused_import
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart' as app_screens;
import 'kingdom_screen.dart';
import 'profile_screen.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/battle_rb.dart';
import '../services/active_battle_service.dart';
import '../services/auth_service.dart';
import '../services/permission_service.dart';
import '../widgets/permission_bottom_sheet.dart';
import 'bot_selection_screen.dart';
import 'matchmaking_screen.dart';
import 'waiting_for_friend_screen.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:upgrader/upgrader.dart';
import '../widget/home/app_showcase.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 1;

  // Showcase Keys
  final GlobalKey _onlineBattleKey = GlobalKey();
  final GlobalKey _friendBattleKey = GlobalKey();
  // final GlobalKey _googleFitKey = GlobalKey();
  final GlobalKey _kingdomButtonKey = GlobalKey();
  final GlobalKey _profileButtonKey = GlobalKey();
  final GlobalKey _stepCountKey = GlobalKey();

  late final List<Widget> _pages;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  late final StreamSubscription _battleStateSubscription;
  @override
  void initState() {
    super.initState();
    _pages = [
      const KingdomScreen(),
      app_screens.HomeScreen(
        onlineBattleKey: _onlineBattleKey,
        friendBattleKey: _friendBattleKey,
        // googleFitKey: _googleFitKey,
        stepCountKey: _stepCountKey,
      ),
      const ProfileScreen(),
    ];
    final battleService = context.read<ActiveBattleService>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (battleService.finalBattleState != null) {
        _showGameOverDialog(battleService.finalBattleState!);
      }
    });

    _battleStateSubscription = battleService.stream.listen((_) {
      if (battleService.finalBattleState != null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        _showGameOverDialog(battleService.finalBattleState!);
      } else if (!battleService.isBattleActive &&
          battleService.currentGame != null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        _showSimpleBattleEndDialog();
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
    final battleService = context.read<ActiveBattleService>();
    final bool isBattleOngoing =
        battleService.currentGame?.gameStatus == GameStatus.ongoing;

    if (state == AppLifecycleState.resumed) {
     if (battleService.isBattleActive &&
          isBattleOngoing && 
          (battleService.timeLeft.isNegative ||
              battleService.timeLeft.inSeconds == 0)) {
        print(
            "App resumed with an ONGOING battle that has 0 time. Ending battle.");
        battleService.endBattle();
      }
    }
  }

  Future<void>? _permissionCheckFuture;

  Future<void> _checkAndShowPermissions() {
    _permissionCheckFuture ??= _doCheckPermissions();
    return _permissionCheckFuture!;
  }

  Future<void> _doCheckPermissions() async {
    final allGranted = await PermissionService.areAllPermissionsGranted();

    if (!allGranted && mounted) {
      await Future.delayed(const Duration(milliseconds: 1000));

      if (!mounted) return;
      await PermissionBottomSheet.show(
        context,
        showCloseButton: true,
      );
    }
  }

  void _showGameOverDialog(Map<String, dynamic> finalState) {
    final authService = context.read<AuthService>();
    final battleService = context.read<ActiveBattleService>();
    final currentUserId = authService.currentUser?.uid;

    final gameState = finalState['finalState'];
    if (gameState == null) return;

    final String? p1Id = battleService.currentGame?.player1Id;
    final String? p2Id = battleService.currentGame?.player2Id;
    if (gameState['result'] == 'ERROR') {
      _showSimpleBattleEndDialog();
      return;
    }

    final winnerId = gameState['winnerId'];
    final result = gameState['result']; // "WIN", "KO", "DRAW"
    final gameType = gameState['gameType']; // 'PVP', 'BOT', 'FRIEND'
    final isKnockout = gameState['isKnockout'] ?? false;
    final rewards =
        gameState['rewards']; // This has winnerCoins, loserCoins, item

    final bool isWinner = winnerId == currentUserId;

    String title;
    String subtitle;
    Color titleBorderColor;
    int baseScore = 0;
    String coinBonusText = ""; // This will hold " - 1000 Win Bonus"
    int? coinsToShow; // This is the TOTAL

    if (result == 'DRAW') {
      title = "It's a Draw!";
      subtitle = "You both fought well!";
      titleBorderColor = Colors.grey;

      if (currentUserId == p1Id) {
        coinsToShow = rewards?['winnerCoins'] ?? 0;
      } else if (currentUserId == p2Id) {
        coinsToShow = rewards?['loserCoins'] ?? 0;
      } else {
        coinsToShow = 0;
      }

      baseScore = coinsToShow ?? 0;
      coinBonusText = " (Draw)";
    } else if (isWinner) {
      if (isKnockout) {
        title = "Winner";
        subtitle = "You won this battle with a\nKnockout.";
        titleBorderColor = const Color(0xFFFFC107);
      } else {
        title = "Winner";
        subtitle = "You won this battle!";
        titleBorderColor = const Color(0xFFFFC107);
      }

      coinsToShow = rewards?['winnerCoins'] ?? 0;

      int bonus = 0;
      if (gameType != 'FRIEND') {
        bonus = isKnockout ? 3000 : 1000;
      }

      baseScore = coinsToShow! + bonus;
      if (baseScore < 0) baseScore = 0;
      if (bonus > 0) {
        coinBonusText = " - ${bonus} ${isKnockout ? 'KO Bonus' : 'Win Bonus'}";
      } else if (gameType == 'FRIEND') {
        coinBonusText = " (Friend Pot)";
      }
    } else {
      // Loser
      title = "Defeat";
      subtitle = "Better luck next time!";
      titleBorderColor = Colors.red;
      coinsToShow = rewards?['loserCoins'] ?? 0;
      baseScore = coinsToShow ?? 0;
      coinBonusText = " (Participation)";
    }

    final rewardItemToShow =
        rewards?['item'] != null && isWinner ? rewards!['item'] : null;

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
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      "${baseScore} coins", // e.g., "1117 coins"
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (coinBonusText.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 4.0), // A small space
                                        child: Text(
                                          coinBonusText, // e.g., " - 1000 Win Bonus"
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                  ],
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

                          final user = await authService
                              .refreshUserProfile(currentUserId!);
                          if (user == null || !mounted) return;

                          print(
                              "--- BATTLE ENDED --- Navigating based on Game Type: '$gameType'");

                          switch (gameType) {
                            case 'PVP':
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) =>
                                      MatchmakingScreen(user: user)));
                              break;
                            case 'BOT':
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) =>
                                      BotSelectionScreen(user: user)));
                              break;
                            case 'FRIEND':
                              break;
                            default:
                              print(
                                  "--- WARNING --- Unknown gameType '$gameType' received. Defaulting to home screen.");
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          battleService.dismissBattleResults();

                          if (!mounted) return;
                          setState(() {
                            _currentIndex = 1;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            color: Color.fromARGB(255, 255, 254, 254),
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

  void _showSimpleBattleEndDialog() {
    final battleService = context.read<ActiveBattleService>();

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
                decoration: const BoxDecoration(
                  color: Color(0xFF2a2a2a),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(color: Colors.red, width: 3),
                    left: BorderSide(color: Colors.red, width: 3),
                    right: BorderSide(color: Colors.red, width: 3),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '⚠️',
                      style: TextStyle(fontSize: 20),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Battle Ended',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '⚠️',
                      style: TextStyle(fontSize: 20),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      "The battle has ended.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Note: We couldn't retrieve your battle results. This might be due to a network issue.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 24),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          battleService.dismissBattleResults();
                          setState(() {
                            _currentIndex = 1;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Close',
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
    const double bottomNavBarHeight =
        kBottomNavigationBarHeight + 30; // More adaptive height

    return ShowCaseWidget(
      blurValue: 1,
      autoPlayDelay: const Duration(seconds: 3),
      builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _checkAndShowPermissions();
          if (context.mounted) {
            await Future.delayed(const Duration(milliseconds: 500));
            _checkAndStartShowcase(context);
          }
        });

        return UpgradeAlert(
          // upgrader: Upgrader(debugDisplayAlways: true), 
          child: AnnotatedRegion<SystemUiOverlayStyle>(
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
                        // Use a more adaptive approach for bottom padding
                        Container(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).padding.bottom +
                                bottomNavBarHeight,
                          ),
                          child: _pages[_currentIndex],
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: _buildBottomNavBar(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );  
      },
    );
  }

  Future<void> _checkAndStartShowcase(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    // V2 key to force re-show for users who experienced the overlap bug
    final bool showcaseShown = prefs.getBool('showcase_shown_v2') ?? false;

    if (!showcaseShown) {
      if (context.mounted) {
        ShowCaseWidget.of(context).startShowCase([
          _stepCountKey,
          _onlineBattleKey,
          _friendBattleKey,
          // _googleFitKey,
          _kingdomButtonKey,
          _profileButtonKey,
          AppShowcase.tutorialInfoKey,
        ]);
        await prefs.setBool('showcase_shown_v2', true);
      }
    }
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        30 +
            MediaQuery.of(context)
                .padding
                .bottom, // Account for device-specific bottom padding
      ),
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
              key: _kingdomButtonKey,
              description: 'Manage your Kingdom\nand upgrades!',
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
              key: _profileButtonKey,
              description: 'View your stats\nand settings',
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
    GlobalKey? key,
    String? description,
  }) {
    final isSelected = _currentIndex == index;
    final content = GestureDetector(
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

    if (key != null && description != null) {
      return Showcase(
        key: key,
        description: description,
        tooltipBackgroundColor: const Color(0xFF1E1E1E),
        textColor: Colors.white,
        tooltipBorderRadius: BorderRadius.circular(12),
        // targetShapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: content,
      );
    }
    return content;
  }
}
