import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/territory.dart';
import 'animated_progress_bar.dart';
import 'status_pill.dart';

class TerritoryCard extends StatefulWidget {
  final Territory territory;
  final bool isOwned;
  final VoidCallback? onAttack;
  final VoidCallback? onReinforce;
  final bool isUnderAttack;

  const TerritoryCard({
    Key? key,
    required this.territory,
    this.isOwned = false,
    this.onAttack,
    this.onReinforce,
    this.isUnderAttack = false,
  }) : super(key: key);

  @override
  State<TerritoryCard> createState() => _TerritoryCardState();
}

class _TerritoryCardState extends State<TerritoryCard>
    with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late AnimationController _pulseController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    if (widget.isUnderAttack) {
      _startAttackAnimation();
    }
  }

  void _startAttackAnimation() {
    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });
    _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(TerritoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isUnderAttack && !oldWidget.isUnderAttack) {
      _startAttackAnimation();
    } else if (!widget.isUnderAttack && oldWidget.isUnderAttack) {
      _shakeController.stop();
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Color get _cardBorderColor {
    if (widget.isUnderAttack) return AppTheme.primaryAttack;
    if (widget.isOwned) return AppTheme.successGold;
    if (widget.territory.status == TerritoryStatus.cooldown) {
      return AppTheme.textGray;
    }
    return AppTheme.primaryDefend;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_shakeAnimation, _pulseAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isUnderAttack ? _pulseAnimation.value : 1.0,
          child: Transform.translate(
            offset: Offset(
              widget.isUnderAttack ? _shakeAnimation.value * 4 * 
                (widget.isUnderAttack ? 1 : 0) : 0,
              0,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _cardBorderColor,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _cardBorderColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          // Territory Icon
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _cardBorderColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: _cardBorderColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // Territory Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.territory.name,
                                  style: AppTextStyles.territoryName,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.territory.ownerNickname ?? 'Unowned',
                                  style: AppTextStyles.ownerName,
                                ),
                              ],
                            ),
                          ),
                          
                          // Status Pill
                          StatusPill(
                            territoryStatus: widget.territory.status,
                            animated: widget.isUnderAttack,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Shield Progress
                      AnimatedProgressBar(
                        progress: widget.territory.currentShield / widget.territory.maxShield,
                        color: widget.isOwned ? AppTheme.primaryDefend : AppTheme.primaryAttack,
                        label: 'Shield',
                        showPercentage: true,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Shield Numbers
                      Row(
                        children: [
                          Text(
                            '${widget.territory.currentShield}',
                            style: AppTextStyles.monoNumbers.copyWith(
                              fontSize: 16,
                              color: AppTheme.primaryDefend,
                            ),
                          ),
                          Text(
                            ' / ',
                            style: AppTextStyles.monoNumbers.copyWith(
                              fontSize: 16,
                              color: AppTheme.textGray,
                            ),
                          ),
                          Text(
                            '${widget.territory.maxShield}',
                            style: AppTextStyles.monoNumbers.copyWith(
                              fontSize: 16,
                              color: AppTheme.textGray,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${widget.territory.currentShield} hits remaining',
                            style: AppTextStyles.statusText.copyWith(
                              color: AppTheme.textGray,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Action Buttons
                      Row(
                        children: [
                          if (widget.isOwned && widget.onReinforce != null)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: widget.onReinforce,
                                style: AppButtonStyles.defendButton,
                                icon: const Icon(Icons.shield, size: 18),
                                label: const Text('Reinforce'),
                              ),
                            )
                          else if (!widget.isOwned && 
                                   widget.territory.status == TerritoryStatus.peaceful &&
                                   widget.onAttack != null)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: widget.onAttack,
                                style: AppButtonStyles.attackButton,
                                icon: const Icon(Icons.rocket_launch, size: 18),
                                label: const Text('Attack'),
                              ),
                            )
                          else if (widget.territory.status == TerritoryStatus.cooldown)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: null,
                                style: AppButtonStyles.warningButton,
                                icon: const Icon(Icons.timer, size: 18),
                                label: Text(_getCooldownText()),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getCooldownText() {
    // Mock cooldown calculation
    return '23h 45m';
  }
}

