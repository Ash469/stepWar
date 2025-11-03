// ignore_for_file: unused_import
import 'package:flutter/material.dart';
import 'string_extension.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:firebase_remote_config/firebase_remote_config.dart';

class MysteryBoxSection extends StatelessWidget {
  final Function(String, int) onOpenBox;
  final bool isOpeningBronze;
  final bool isOpeningSilver;
  final bool isOpeningGold;
  final Duration bronzeTimeLeft;
  final Duration silverTimeLeft;
  final Duration goldTimeLeft;

  const MysteryBoxSection({
    super.key,
    required this.onOpenBox,
    required this.isOpeningBronze,
    required this.isOpeningSilver,
    required this.isOpeningGold,
    required this.bronzeTimeLeft,
    required this.silverTimeLeft,
    required this.goldTimeLeft,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final remoteConfig = context.read<FirebaseRemoteConfig>();
    final bronzePrice = remoteConfig.getInt('bronze_box_price');
    final silverPrice = remoteConfig.getInt('silver_box_price');
    final goldPrice = remoteConfig.getInt('gold_box_price');
  
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildMysteryBox(
          imagePath: 'assets/images/bronze_box.png',
          boxType: 'bronze',
         price: bronzePrice,
          isLoading: isOpeningBronze,
          timeLeft: bronzeTimeLeft,
        ),
        _buildMysteryBox(
          imagePath: 'assets/images/silver_box.png',
          boxType: 'silver',
         price: silverPrice,
          isLoading: isOpeningSilver,
          timeLeft: silverTimeLeft,
        ),
        _buildMysteryBox(
          imagePath: 'assets/images/gold_box.png',
          boxType: 'gold',
          price: goldPrice,
          isLoading: isOpeningGold,
          timeLeft: goldTimeLeft,
        ),
      ],
    );
  }

  Widget _buildMysteryBox({
    required String imagePath,
    required String boxType,
    required int price,
    required bool isLoading,
    required Duration timeLeft,
  }) {
    final bool isOpenedToday = timeLeft > Duration.zero;

    return Expanded(
      child: GestureDetector(
        onTap: (isOpenedToday || isLoading) ? null : () => onOpenBox(boxType, price),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      imagePath,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    if (isLoading)
                      const CircularProgressIndicator(color: Colors.white),
                    if (isOpenedToday && !isLoading)
                      Container(
                        height: 120,
                        width: double.infinity,
                        color: Colors.black.withOpacity(0.6),
                        child: const Icon(Icons.lock_clock, color: Colors.white, size: 40),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isOpenedToday ? Colors.transparent : Colors.yellow.shade800,
                  borderRadius: BorderRadius.circular(20),
                  border: isOpenedToday ? Border.all(color: Colors.grey.shade700) : null,
                ),
                child: isOpenedToday
                    ? Text(
                        _formatDuration(timeLeft),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/coin_icon.png',
                            width: 20,
                            height: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            price.toString(),
                            style: const TextStyle(color: Colors.white),
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
}
