import 'dart:async';

import 'package:flutter/material.dart';
import 'home_screen.dart' as app_screens;
import 'kingdom_screen.dart';
import 'profile_screen.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // Make sure provider is imported
import '../services/active_battle_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
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
        battleService.dismissBattleResults();
      }
    });
  }

  @override
  void dispose() {
    _battleStateSubscription.cancel();
    super.dispose();
  }

  void _showGameOverDialog(Map<String, dynamic> finalState) {
    // This is your dialog logic, now living in the MainScreen
    // You can customize this with the new design from your image
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: const Text("👑 Winner 👑",
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
        content: Text(
            "You won! Rewards: ${finalState['finalState']?['rewards']?['coins'] ?? 0} coins.",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            child: const Text('OK', style: TextStyle(color: Color(0xFFFFC107))),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
        ],
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
                  // ✨ THE CHANGE IS HERE ✨
                  // This will now create a new instance of the screen on every tab switch,
                  // causing initState() and your _loadInitialData() function to run again.
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
    final labelColor = isSelected ? Colors.black : Colors.white;

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.translucent,
      child: Container(
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
                  color: labelColor,
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
