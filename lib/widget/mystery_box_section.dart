// ignore_for_file: unused_import
import 'package:flutter/material.dart';
import 'string_extension.dart';
import 'package:provider/provider.dart'; 
import 'package:firebase_remote_config/firebase_remote_config.dart';

class MysteryBoxSection extends StatefulWidget {
  final Function(String, int) onOpenBox;
  final bool isOpeningBronze;
  final bool isOpeningSilver;
  final bool isOpeningGold;

  const MysteryBoxSection({
    super.key,
    required this.onOpenBox,
    required this.isOpeningBronze,
    required this.isOpeningSilver,
    required this.isOpeningGold,
  });

  @override
  State<MysteryBoxSection> createState() => _MysteryBoxSectionState();
}

class _MysteryBoxSectionState extends State<MysteryBoxSection> {
  @override
  void initState() {
    super.initState();
    _setupRemoteConfigListener();
  }

  void _setupRemoteConfigListener() {
    final remoteConfig = FirebaseRemoteConfig.instance;
    remoteConfig.onConfigUpdated.listen((event) async {
      await remoteConfig.activate();
      if (mounted) {
        setState(() {
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final remoteConfig = context.read<FirebaseRemoteConfig>();
    // Fetch values directly - they will be updated after activate() and rebuild
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
          isLoading: widget.isOpeningBronze,
        ),
        _buildMysteryBox(
          imagePath: 'assets/images/silver_box.png',
          boxType: 'silver',
          price: silverPrice,
          isLoading: widget.isOpeningSilver,
        ),
        _buildMysteryBox(
          imagePath: 'assets/images/gold_box.png',
          boxType: 'gold',
          price: goldPrice,
          isLoading: widget.isOpeningGold,
        ),
      ],
    );
  }

  Widget _buildMysteryBox({
    required String imagePath,
    required String boxType,
    required int price,
    required bool isLoading,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: isLoading ? null : () => widget.onOpenBox(boxType, price),
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
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade800,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
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
