import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'app_showcase.dart';

class HomeHeader extends StatelessWidget {
  final String username;
  final int coins;
  final VoidCallback? onTutorialTap;

  const HomeHeader({
    super.key,
    required this.username,
    required this.coins,
    this.onTutorialTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child:
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome Back,',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 18),
            ),
            Text(
              username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
    ),
        Row(
          children: [
            // Tutorial info icon with showcase
            Showcase(
              key: AppShowcase.tutorialInfoKey,
              title: 'Need Help?',
              description: 'Tap here anytime to see how the game works!',
              tooltipBackgroundColor: const Color(0xFF1E1E1E),
              textColor: Colors.white,
              tooltipBorderRadius: BorderRadius.circular(12),
              targetShapeBorder: const CircleBorder(),
              child: GestureDetector(
                onTap: onTutorialTap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: Colors.white70,
                    size: 22,
                  ),
                ),
              ),
            ),
            // Coins display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color.fromARGB(213, 249, 188, 35),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Image(
                      image: AssetImage('assets/images/coin_icon.png'),
                      width: 24,
                      height: 24),
                  const SizedBox(width: 8),
                  Text(
                    coins.toString(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}