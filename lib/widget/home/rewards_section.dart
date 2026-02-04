import 'package:flutter/material.dart';
import 'package:stepwars_app/screens/kingdom_screen.dart' show KingdomItem;
import 'package:cached_network_image/cached_network_image.dart';

class RewardsSection extends StatelessWidget {
  final KingdomItem? latestReward;
  const RewardsSection({super.key, this.latestReward});

  @override
  Widget build(BuildContext context) {
    if (latestReward == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_moon_outlined,
                    color: Colors.grey.shade400, size: 30),
                const SizedBox(width: 12),
                const Text("No Rewards Yet",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Win battles to collect new rewards for your Kingdom!",
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              latestReward!.imagePath.isNotEmpty
                  ? (latestReward!.imagePath.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: latestReward!.imagePath,
                          height: 30,
                          errorWidget: (context, url, error) => Icon(
                              Icons.location_city,
                              color: latestReward!.rarityColor,
                              size: 30),
                        )
                      : Image.asset(
                          latestReward!.imagePath,
                          height: 30,
                          errorBuilder: (c, e, s) => Icon(Icons.location_city,
                              color: latestReward!.rarityColor, size: 30),
                        ))
                  : Icon(Icons.location_city,
                      color: latestReward!.rarityColor, size: 30),
              const SizedBox(width: 12),
              Text(latestReward!.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            latestReward!.description,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
