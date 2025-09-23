import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/territory.dart';

class StatusPill extends StatelessWidget {
  // For territory status
  final TerritoryStatus? territoryStatus;

  // For battle statistics
  final String? label;
  final String? value;
  final Color? color;

  final bool animated;

  const StatusPill({
    Key? key,
    this.territoryStatus,
    this.label,
    this.value,
    this.color,
    this.animated = true,
  })  : assert(
          (territoryStatus != null) ||
              (label != null && value != null && color != null),
          'Either provide territoryStatus or (label, value, color) combination',
        ),
        super(key: key);

  // Get territory status colors and text
  Color get _backgroundColor {
    if (territoryStatus != null) {
      switch (territoryStatus!) {
        case TerritoryStatus.peaceful:
          return AppTheme.successGreen;
        case TerritoryStatus.underAttack:
          return AppTheme.primaryAttack;
        case TerritoryStatus.cooldown:
          return AppTheme.textGray;
      }
    }
    return color ?? AppTheme.textGray;
  }

  Color get _textColor {
    if (territoryStatus != null) {
      switch (territoryStatus!) {
        case TerritoryStatus.peaceful:
        case TerritoryStatus.underAttack:
          return AppTheme.textWhite;
        case TerritoryStatus.cooldown:
          return AppTheme.backgroundDark;
      }
    }
    return color ?? AppTheme.textWhite;
  }

  String get _statusText {
    if (territoryStatus != null) {
      switch (territoryStatus!) {
        case TerritoryStatus.peaceful:
          return 'Peaceful';
        case TerritoryStatus.underAttack:
          return 'Under Attack';
        case TerritoryStatus.cooldown:
          return 'Cooldown';
      }
    }
    return '';
  }

  IconData get _statusIcon {
    if (territoryStatus != null) {
      switch (territoryStatus!) {
        case TerritoryStatus.peaceful:
          return Icons.check_circle;
        case TerritoryStatus.underAttack:
          return Icons.warning;
        case TerritoryStatus.cooldown:
          return Icons.timer;
      }
    }
    return Icons.info;
  }

  @override
  Widget build(BuildContext context) {
    Widget pill;

    if (territoryStatus != null) {
      // Territory status pill
      pill = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _backgroundColor.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _statusIcon,
              size: 14,
              color: _textColor,
            ),
            const SizedBox(width: 4),
            Text(
              _statusText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _textColor,
              ),
            ),
          ],
        ),
      );
    } else {
      // Battle statistics pill
      pill = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color!.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color!.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              value!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label!,
              style: TextStyle(
                fontSize: 12,
                color: color!.withOpacity(0.8),
              ),
            ),
          ],
        ),
      );
    }

    if (!animated) return pill;

    // Add animations based on type
    if (territoryStatus != null) {
      switch (territoryStatus!) {
        case TerritoryStatus.peaceful:
          return pill.animate()
              .fadeIn(duration: const Duration(milliseconds: 300))
              .scale(begin: const Offset(0.8, 0.8));
        case TerritoryStatus.underAttack:
          return pill.animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: const Duration(milliseconds: 1000));
        case TerritoryStatus.cooldown:
          return pill.animate()
              .fadeIn(duration: const Duration(milliseconds: 300));
      }
    }

    return pill.animate()
        .fadeIn(duration: const Duration(milliseconds: 300))
        .scale(begin: const Offset(0.8, 0.8));
  }
}
