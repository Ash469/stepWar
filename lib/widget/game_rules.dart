import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:firebase_remote_config/firebase_remote_config.dart';

class GameRulesWidget extends StatelessWidget {
  const GameRulesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final remoteConfig = context.read<FirebaseRemoteConfig>();
    final koDifference = 200;
    final drawDifference = 50;
    // final koDifference = remoteConfig.getInt('ko_diff');
    // final drawDifference = remoteConfig.getInt('draw_diff');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Game Rules",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            color: Colors.white,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Understand the rules to win every battle.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white70,
            fontFamily: 'Montserrat',
          ),
        ),
        const SizedBox(height: 24),
        _buildRuleItem(
          'assets/images/medel.png',
          "Win",
          "Most steps after timer ends", 
        ),
        const SizedBox(height: 16),
        _buildRuleItem(
          'assets/images/ko_image.png',
          "KO Victory",
         "Lead by $koDifference steps",
        ),
        const SizedBox(height: 16),
        _buildRuleItem(
          'assets/images/flag.png',
          "Draw",
         "Less than $drawDifference steps difference",
        ),
      ],
    );
  }

  Widget _buildRuleItem(String imagePath, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFFC107), 
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.amber,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
