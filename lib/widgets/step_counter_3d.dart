import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'dart:math' as math;

class StepCounter3D extends StatefulWidget {
  final int steps;
  final String label;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback? onTap;

  const StepCounter3D({
    Key? key,
    required this.steps,
    required this.label,
    this.primaryColor = AppTheme.successGold,
    this.secondaryColor = AppTheme.primaryAttack,
    this.onTap,
  }) : super(key: key);

  @override
  State<StepCounter3D> createState() => _StepCounter3DState();
}

class _StepCounter3DState extends State<StepCounter3D>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _countController;

  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<int> _countAnimation;

  int _previousSteps = 0;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _countController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _countAnimation = IntTween(
      begin: 0,
      end: widget.steps,
    ).animate(CurvedAnimation(
      parent: _countController,
      curve: Curves.easeOut,
    ));

    _previousSteps = widget.steps;
    _rotationController.repeat();
    _countController.forward();
  }

  @override
  void didUpdateWidget(StepCounter3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.steps != widget.steps) {
      _countAnimation = IntTween(
        begin: _previousSteps,
        end: widget.steps,
      ).animate(CurvedAnimation(
        parent: _countController,
        curve: Curves.easeOut,
      ));

      _countController.reset();
      _countController.forward();

      // Pulse animation when steps increase
      if (widget.steps > _previousSteps) {
        _pulseController.forward().then((_) {
          _pulseController.reverse();
        });
      }

      _previousSteps = widget.steps;
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _rotationAnimation,
          _pulseAnimation,
          _countAnimation,
        ]),
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer rotating ring
                  Transform.rotate(
                    angle: _rotationAnimation.value * 2 * 3.14159,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            widget.primaryColor.withOpacity(0.1),
                            widget.primaryColor.withOpacity(0.8),
                            widget.secondaryColor.withOpacity(0.8),
                            widget.primaryColor.withOpacity(0.1),
                          ],
                          stops: const [0.0, 0.3, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Middle ring
                  Transform.rotate(
                    angle: -_rotationAnimation.value * 1.5 * 3.14159,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            widget.secondaryColor.withOpacity(0.1),
                            widget.secondaryColor.withOpacity(0.6),
                            widget.primaryColor.withOpacity(0.6),
                            widget.secondaryColor.withOpacity(0.1),
                          ],
                          stops: const [0.0, 0.4, 0.6, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Inner core
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          widget.primaryColor.withOpacity(0.8),
                          widget.primaryColor.withOpacity(0.3),
                          AppTheme.backgroundSecondary,
                        ],
                        stops: const [0.0, 0.7, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.primaryColor.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Step count
                        Text(
                          _countAnimation.value.toString(),
                          style: AppTextStyles.monoNumbers.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: widget.primaryColor,
                          ),
                        ),

                        // Label
                        Text(
                          widget.label,
                          style: AppTextStyles.statusText.copyWith(
                            fontSize: 10,
                            color: AppTheme.textGray,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Floating particles
                  ...List.generate(6, (index) {
                    final angle = (index * 60.0) * (math.pi / 180);
                    final radius = 90.0;
                    final x = radius *
                        math.cos(
                            angle + _rotationAnimation.value * 2 * math.pi);
                    final y = radius *
                        math.sin(
                            angle + _rotationAnimation.value * 2 * math.pi);

                    return Transform.translate(
                      offset: Offset(x, y),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.primaryColor.withOpacity(0.6),
                          boxShadow: [
                            BoxShadow(
                              color: widget.primaryColor.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
