import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/territory.dart';
import '../widgets/animated_progress_bar.dart';

class BattleTussleView extends StatefulWidget {
  final Territory territory;
  final bool isAttacker;
  final VoidCallback? onConvertSteps;
  final VoidCallback? onEndBattle;

  const BattleTussleView({
    Key? key,
    required this.territory,
    required this.isAttacker,
    this.onConvertSteps,
    this.onEndBattle,
  }) : super(key: key);

  @override
  State<BattleTussleView> createState() => _BattleTussleViewState();
}

class _BattleTussleViewState extends State<BattleTussleView>
    with TickerProviderStateMixin {
  late AnimationController _battleController;
  late AnimationController _explosionController;
  late AnimationController _pulseController;
  
  late Animation<double> _battleAnimation;
  late Animation<double> _explosionAnimation;
  late Animation<double> _pulseAnimation;
  
  int _playerSteps = 3420;
  int _enemySteps = 2890;
  bool _isConverting = false;
  
  @override
  void initState() {
    super.initState();
    
    _battleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _explosionController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _battleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _battleController,
      curve: Curves.easeInOut,
    ));
    
    _explosionAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _explosionController,
      curve: Curves.easeOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _battleController.repeat();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _battleController.dispose();
    _explosionController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            AppTheme.primaryAttack.withOpacity(0.1),
            AppTheme.backgroundDark,
            AppTheme.backgroundSecondary,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    onPressed: widget.onEndBattle,
                    icon: const Icon(Icons.close),
                    color: AppTheme.textWhite,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Battle for ${widget.territory.name}',
                          style: AppTextStyles.territoryName.copyWith(
                            fontSize: 20,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          widget.isAttacker ? 'Attacking' : 'Defending',
                          style: AppTextStyles.statusText.copyWith(
                            color: widget.isAttacker ? 
                                AppTheme.primaryAttack : 
                                AppTheme.primaryDefend,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the close button
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Battle Animation Area
              Expanded(
                flex: 2,
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _battleAnimation,
                    _explosionAnimation,
                    _pulseAnimation,
                  ]),
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background energy field
                        Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppTheme.primaryAttack.withOpacity(0.3),
                                  AppTheme.primaryDefend.withOpacity(0.3),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        // Territory shield visualization
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.primaryDefend,
                              width: 3,
                            ),
                            color: AppTheme.primaryDefend.withOpacity(0.1),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shield,
                                  size: 40,
                                  color: AppTheme.primaryDefend,
                                ),
                                Text(
                                  '${widget.territory.shieldLevel}',
                                  style: AppTextStyles.monoNumbers.copyWith(
                                    fontSize: 24,
                                    color: AppTheme.primaryDefend,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Attack missiles
                        if (widget.isAttacker) ...[
                          for (int i = 0; i < 3; i++)
                            Transform.translate(
                              offset: Offset(
                                -150 + (300 * _battleAnimation.value) + (i * 20),
                                -50 + (i * 30),
                              ),
                              child: Transform.rotate(
                                angle: 0.5,
                                child: Icon(
                                  Icons.rocket,
                                  color: AppTheme.primaryAttack,
                                  size: 24,
                                ),
                              ),
                            ),
                        ],
                        
                        // Explosion effects
                        if (_explosionAnimation.value > 0)
                          Transform.scale(
                            scale: _explosionAnimation.value * 3,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.successGold.withOpacity(
                                  1.0 - _explosionAnimation.value,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Shield Progress
              AnimatedProgressBar(
                progress: widget.territory.shieldLevel / widget.territory.shieldMax,
                color: AppTheme.primaryDefend,
                label: 'Territory Shield',
                height: 12,
              ),
              
              const SizedBox(height: 8),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Shield: ${widget.territory.shieldLevel}/${widget.territory.shieldMax}',
                    style: AppTextStyles.monoNumbers.copyWith(
                      color: AppTheme.primaryDefend,
                    ),
                  ),
                  Text(
                    '${((widget.territory.shieldLevel / widget.territory.shieldMax) * 100).round()}%',
                    style: AppTextStyles.monoNumbers.copyWith(
                      color: AppTheme.primaryDefend,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Player vs Enemy Stats
              Row(
                children: [
                  Expanded(
                    child: _buildPlayerCard(
                      'Your Power',
                      _playerSteps,
                      widget.isAttacker ? AppTheme.primaryAttack : AppTheme.primaryDefend,
                      widget.isAttacker ? Icons.rocket_launch : Icons.shield,
                      isPlayer: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.backgroundSecondary,
                    ),
                    child: Text(
                      'VS',
                      style: AppTextStyles.statusText.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textWhite,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPlayerCard(
                      'Enemy Power',
                      _enemySteps,
                      widget.isAttacker ? AppTheme.primaryDefend : AppTheme.primaryAttack,
                      widget.isAttacker ? Icons.shield : Icons.rocket_launch,
                      isPlayer: false,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isConverting ? null : _convertSteps,
                  style: widget.isAttacker ? 
                      AppButtonStyles.attackButton : 
                      AppButtonStyles.defendButton,
                  icon: Icon(
                    widget.isAttacker ? Icons.rocket_launch : Icons.shield,
                    size: 24,
                  ),
                  label: Text(
                    _isConverting ? 
                        'Converting...' : 
                        'Convert Steps → ${widget.isAttacker ? 'Missile' : 'Shield'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Battle Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundSecondary.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Battle updates every 5-10 seconds',
                      style: AppTextStyles.statusText.copyWith(
                        color: AppTheme.textGray,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isAttacker ? 
                          '10 Attack Points = 1 Shield Hit' :
                          '100 Steps = +1 Shield Point',
                      style: AppTextStyles.statusText.copyWith(
                        color: AppTheme.textWhite,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCard(
    String title,
    int steps,
    Color color,
    IconData icon,
    {required bool isPlayer}
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppTextStyles.statusText.copyWith(
              color: AppTheme.textGray,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            steps.toString(),
            style: AppTextStyles.monoNumbers.copyWith(
              fontSize: 20,
              color: color,
            ),
          ),
          Text(
            'steps',
            style: AppTextStyles.statusText.copyWith(
              color: AppTheme.textGray,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  void _convertSteps() {
    setState(() {
      _isConverting = true;
    });
    
    // Trigger explosion animation
    _explosionController.forward().then((_) {
      _explosionController.reset();
    });
    
    // Simulate conversion delay
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isConverting = false;
        if (widget.isAttacker) {
          _playerSteps += 500; // Mock step addition
        } else {
          _playerSteps += 300; // Mock shield reinforcement
        }
      });
      
      widget.onConvertSteps?.call();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isAttacker ? 
                'Attack launched!' : 
                'Shield reinforced!',
          ),
          backgroundColor: widget.isAttacker ? 
              AppTheme.primaryAttack : 
              AppTheme.primaryDefend,
        ),
      );
    });
  }
}

