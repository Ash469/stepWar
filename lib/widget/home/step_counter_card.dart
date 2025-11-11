import 'package:flutter/material.dart';

class StepCounterCard extends StatelessWidget {
  final int steps;
  const StepCounterCard({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWideScreen = constraints.maxWidth > 500;
        
        return Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(16.0),
            gradient: LinearGradient(
              colors: [Colors.yellow.shade800, Colors.yellow.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: isWideScreen
              ? _buildWideLayout()
              : _buildCompactLayout(),
        );
      },
    );
  }

  Widget _buildWideLayout() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Today's Steps",
                  style: TextStyle(color: Colors.black, fontSize: 18)),
              const SizedBox(height: 8),
              Text(
                steps.toString(),
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 42,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const Icon(Icons.directions_walk, size: 60, color: Colors.black),
      ],
    );
  }

  Widget _buildCompactLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Today's Steps",
                style: TextStyle(color: Colors.black, fontSize: 18)),
            Icon(Icons.directions_walk, size: 40, color: Colors.black),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          steps.toString(),
          style: const TextStyle(
              color: Colors.black,
              fontSize: 36,
              fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}