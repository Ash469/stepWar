import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'app_showcase.dart';

class StepCounterShowcase extends StatelessWidget {
  final Widget child;

  const StepCounterShowcase({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Showcase(
      key: AppShowcase.stepCountKey,
      title: 'Daily Steps',
      description: 'Your steps are your power!\nWalk more to collect rewards.',
      tooltipBackgroundColor: const Color(0xFF1E1E1E),
      textColor: Colors.white,
      tooltipBorderRadius: BorderRadius.circular(12),
      targetShapeBorder: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
