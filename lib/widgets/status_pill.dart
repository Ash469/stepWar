import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/territory.dart';

class StatusPill extends StatelessWidget {
  final TerritoryStatus status;
  final bool animated;

  const StatusPill({
    Key? key,
    required this.status,
    this.animated = true,
  }) : super(key: key);

  Color get _backgroundColor {
    switch (status) {
      case TerritoryStatus.peaceful:
        return AppTheme.successGreen;
      case TerritoryStatus.underAttack:
        return AppTheme.primaryAttack;
      case TerritoryStatus.cooldown:
        return AppTheme.textGray;
    }
  }

  Color get _textColor {
    switch (status) {
      case TerritoryStatus.peaceful:
      case TerritoryStatus.underAttack:
        return AppTheme.textWhite;
      case TerritoryStatus.cooldown:
        return AppTheme.backgroundDark;
    }
  }

  String get _statusText {
    switch (status) {
      case TerritoryStatus.peaceful:
        return 'Idle';
      case TerritoryStatus.underAttack:
        return 'In Battle';
      case TerritoryStatus.cooldown:
        return 'Cooldown';
    }
  }

  IconData get _statusIcon {
    switch (status) {
      case TerritoryStatus.peaceful:
        return Icons.check_circle;
      case TerritoryStatus.underAttack:
        return Icons.warning;
      case TerritoryStatus.cooldown:
        return Icons.timer;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget pill = Container(
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
            style: AppTextStyles.statusText.copyWith(
              color: _textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (!animated) return pill;

    // Add animations based on status
    switch (status) {
      case TerritoryStatus.peaceful:
        return pill
            .animate()
            .fadeIn(duration: const Duration(milliseconds: 300))
            .scale(begin: const Offset(0.8, 0.8));
      
      case TerritoryStatus.underAttack:
        return pill
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(
              duration: const Duration(milliseconds: 1000),
              color: Colors.white.withOpacity(0.5),
            );
      
      case TerritoryStatus.cooldown:
        return pill
            .animate()
            .fadeIn(duration: const Duration(milliseconds: 300));
    }
  }
}

