import 'package:flutter/material.dart';

class ScorecardSection extends StatelessWidget {
  final Map<String, dynamic> stats;
  const ScorecardSection({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final battlesWon = stats['battlesWon']?.toString() ?? '0';
    final knockouts = stats['knockouts']?.toString() ?? '0';
    final totalBattles = stats['totalBattles']?.toString() ?? '0';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildScorecardItem(
            'assets/images/battle_won.png', battlesWon, 'Battle won'),
        _buildScorecardItem('assets/images/ko_won.png', knockouts, 'Knockouts'),
        _buildScorecardItem(
            'assets/images/coin_won.png', totalBattles, 'Total Battles'),
      ],
    );
  }

  Widget _buildScorecardItem(String imagePath, String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imagePath.isNotEmpty) Image.asset(imagePath, height: 40),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Text(
              label,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}