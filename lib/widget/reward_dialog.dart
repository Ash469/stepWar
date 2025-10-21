import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class RewardDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget rewardContent;

  const RewardDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.rewardContent,
  });

  @override
  State<RewardDialog> createState() => _RewardDialogState();
}

class _RewardDialogState extends State<RewardDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  final List<ConfettiParticle> _confetti = [];
  final Random _random = Random();
  late Timer _confettiTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    // Generate confetti particles
    for (int i = 0; i < 50; i++) {
      _confetti.add(ConfettiParticle(
        color: Colors.primaries[_random.nextInt(Colors.primaries.length)],
        startPosition: Offset(_random.nextDouble() * 400 - 50, -20),
        startVelocity: Offset(_random.nextDouble() * 2 - 1, _random.nextDouble() * 4 + 2),
      ));
    }

    // Animate confetti
    _confettiTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        for (var p in _confetti) {
          p.update();
        }
      });
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    _confettiTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: SizedBox(
        height: 450,
        width: 350,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Confetti animation
            CustomPaint(
              size: const Size(350, 450),
              painter: ConfettiPainter(particles: _confetti),
            ),
            // --- MODIFIED: Wrapped Image.asset with Opacity ---
            Opacity(
              opacity: 0.7, // Makes the image semi-transparent
              child: Image.asset(
                'assets/images/box.png',
                width: 300,
                height: 300,
              ),
            ),
            // Main Content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                       boxShadow: [
                          BoxShadow(
                            color: Colors.yellow.withOpacity(0.6),
                            blurRadius: 20,
                            spreadRadius: 5
                          )
                       ]
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: const Color.fromARGB(163, 255, 217, 0),
                      child: widget.rewardContent,
                    ),
  
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  style: const TextStyle(
                      color: Color.fromARGB(255, 255, 234, 0),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [ // Added shadow for better readability
                        Shadow(
                          blurRadius: 2.0,
                          color: Colors.white54,
                          offset: Offset(1.0, 1.0),
                        ),
                      ]),
                ),
                if (widget.subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      widget.subtitle,
                      style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                           shadows: [ // Added shadow
                            Shadow(
                              blurRadius: 2.0,
                              color: Colors.white38,
                              offset: Offset(1.0, 1.0),
                            ),
                          ]),
                    ),
                  ),
                const Spacer(flex: 3),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 50, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('Claim Reward',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                 const Spacer(flex: 1),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Helper classes for confetti animation
class ConfettiParticle {
  Offset position;
  Offset velocity;
  Color color;
  final double gravity = 0.1;
  final double airResistance = 0.99;

  ConfettiParticle({
    required this.color,
    required Offset startPosition,
    required Offset startVelocity,
  })  : position = startPosition,
        velocity = startVelocity;

  void update() {
    velocity = Offset(velocity.dx * airResistance, velocity.dy + gravity);
    position += velocity;
  }
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;

  ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var p in particles) {
      paint.color = p.color;
      canvas.drawCircle(p.position, 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

