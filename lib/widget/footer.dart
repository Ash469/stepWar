import 'package:flutter/material.dart';

class StepWarsFooter extends StatelessWidget {
  const StepWarsFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      alignment: Alignment.topCenter,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'STEP WARS',
            style: TextStyle(
              color: Color.fromARGB(255, 235, 252, 1),
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.favorite, color: Colors.yellow.shade700, size: 24),
        ],
      ),
    );
  }
}
