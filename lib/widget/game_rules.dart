import 'package:flutter/material.dart';

class GameRulesWidget extends StatelessWidget {
  const GameRulesWidget({super.key});

  @override
  Widget build(BuildContext context) {
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
          "Most steps after 10 min",
        ),
        const SizedBox(height: 16),
        _buildRuleItem(
          'assets/images/ko_image.png',
          "KO Victory",
          "Lead by 200 steps",
        ),
        const SizedBox(height: 16),
        _buildRuleItem(
          'assets/images/flag.png',
          "Draw",
          "Less than 50 steps difference",
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
