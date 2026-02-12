import 'package:flutter/material.dart';

class GameCard extends StatelessWidget {
  final String title;
  final String description;
  final int level;
  final int reward;
  final int entryFee;
  final String imagePath;
  final String coinImagePath;
  final VoidCallback onTap;

  const GameCard({
    Key? key,
    required this.title,
    required this.description,
    required this.level,
    required this.reward,
    required this.entryFee,
    required this.imagePath,
    required this.coinImagePath,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const kGoldColor = Colors.amber;
    const kCardBgColor = Colors.transparent;
    const kHeaderBgColor = Color(0xFF2C2C2C);

    return Container(
      decoration: const BoxDecoration(
        color: kCardBgColor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. REWARD HEADER
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: kHeaderBgColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Reward: ",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Image.asset(coinImagePath, width: 16, height: 16),
                const SizedBox(width: 4),
                Text(
                  "$reward",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // 2. CARD BODY
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _HexagonAvatar(imagePath: imagePath),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Level $level",
                        style: const TextStyle(
                          color: kGoldColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        title, // Logic applied when calling this widget
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. ENTRY FEE AREA (Only this part is clickable)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Ink(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  color: kGoldColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "ENTRY FEE: ",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    Image.asset(coinImagePath, width: 18, height: 18),
                    const SizedBox(width: 4),
                    Text(
                      "$entryFee",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HexagonAvatar extends StatelessWidget {
  final String imagePath;

  const _HexagonAvatar({Key? key, required this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const double frameSize = 90;

    return SizedBox(
      width: frameSize,
      height: frameSize,
      child: Stack(
        alignment: Alignment.center,
        children: [

          Image.asset(
            'assets/images/hexagon.png',
            width: frameSize,
            height: frameSize,
            fit: BoxFit.contain,
          ),

          ClipPath(
            clipper: _HexagonClipper(),
            child: Container(
              width: frameSize * 0.75,
              height: frameSize * 0.75,
              padding: const EdgeInsets.all(10.0),
              decoration: const BoxDecoration(
                color: Colors.black,
              ),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.person, color: Colors.amber, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width * 0.5, 0);
    path.lineTo(size.width, size.height * 0.25);
    path.lineTo(size.width, size.height * 0.75);
    path.lineTo(size.width * 0.5, size.height);
    path.lineTo(0, size.height * 0.75);
    path.lineTo(0, size.height * 0.25);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
