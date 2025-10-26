import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  final String username;
  final int coins;

  const HomeHeader({
    super.key,
    required this.username,
    required this.coins,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome Back,',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 18),
            ),
            Text(
              username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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
    );
  }
}