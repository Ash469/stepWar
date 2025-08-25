import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/territory.dart';
import '../widgets/territory_card.dart';
import 'dart:math' as math;

class WorldScreen extends StatefulWidget {
  const WorldScreen({Key? key}) : super(key: key);

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late Animation<double> _backgroundAnimation;
  
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Unowned', 'Peaceful', 'Under Attack', 'Cooldown'];

  // Mock territories data
  final List<Territory> territories = [
    const Territory(
      id: 'tokyo_001',
      name: 'Tokyo',
      owner: 'ShadowStride',
      shieldLevel: 2,
      shieldMax: 5,
      status: TerritoryStatus.peaceful,
    ),
    const Territory(
      id: 'bhutan_001',
      name: 'Bhutan',
      owner: null,
      shieldLevel: 1,
      shieldMax: 5,
      status: TerritoryStatus.peaceful,
    ),
    const Territory(
      id: 'london_001',
      name: 'London',
      owner: 'WarriorQueen',
      shieldLevel: 4,
      shieldMax: 5,
      status: TerritoryStatus.underAttack,
    ),
    const Territory(
      id: 'newyork_001',
      name: 'New York',
      owner: 'StepMaster',
      shieldLevel: 5,
      shieldMax: 5,
      status: TerritoryStatus.cooldown,
    ),
    const Territory(
      id: 'sydney_001',
      name: 'Sydney',
      owner: 'FitnessGuru',
      shieldLevel: 3,
      shieldMax: 5,
      status: TerritoryStatus.peaceful,
    ),
    const Territory(
      id: 'cairo_001',
      name: 'Cairo',
      owner: null,
      shieldLevel: 2,
      shieldMax: 5,
      status: TerritoryStatus.peaceful,
    ),
    const Territory(
      id: 'moscow_001',
      name: 'Moscow',
      owner: 'IronWalker',
      shieldLevel: 1,
      shieldMax: 5,
      status: TerritoryStatus.underAttack,
    ),
    const Territory(
      id: 'rio_001',
      name: 'Rio de Janeiro',
      owner: 'BeachRunner',
      shieldLevel: 4,
      shieldMax: 5,
      status: TerritoryStatus.peaceful,
    ),
  ];

  @override
  void initState() {
    super.initState();
    
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    );
    
    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.linear,
    ));
    
    _backgroundController.repeat();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  List<Territory> get filteredTerritories {
    switch (_selectedFilter) {
      case 'Unowned':
        return territories.where((t) => t.owner == null).toList();
      case 'Peaceful':
        return territories.where((t) => t.status == TerritoryStatus.peaceful).toList();
      case 'Under Attack':
        return territories.where((t) => t.status == TerritoryStatus.underAttack).toList();
      case 'Cooldown':
        return territories.where((t) => t.status == TerritoryStatus.cooldown).toList();
      default:
        return territories;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(
                  0.4 * math.sin(_backgroundAnimation.value * 0.8),
                  0.3 * math.cos(_backgroundAnimation.value),
                ),
                radius: 1.8,
                colors: [
                  AppTheme.backgroundDark,
                  AppTheme.backgroundSecondary.withOpacity(0.8),
                  AppTheme.backgroundDark,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'World Map',
                          style: Theme.of(context).textTheme.headlineLarge,
                        )
                            .animate()
                            .fadeIn(duration: const Duration(milliseconds: 600))
                            .slideX(begin: -0.3),
                        
                        const SizedBox(height: 8),
                        
                        Text(
                          '${territories.length} territories available for conquest',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                            .animate()
                            .fadeIn(delay: const Duration(milliseconds: 300))
                            .slideX(begin: -0.3),
                      ],
                    ),
                  ),
                  
                  // Filter Chips
                  Container(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filters.length,
                      itemBuilder: (context, index) {
                        final filter = _filters[index];
                        final isSelected = filter == _selectedFilter;
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedFilter = filter;
                              });
                            },
                            backgroundColor: AppTheme.backgroundSecondary,
                            selectedColor: AppTheme.primaryAttack.withOpacity(0.3),
                            checkmarkColor: AppTheme.primaryAttack,
                            labelStyle: TextStyle(
                              color: isSelected ? AppTheme.primaryAttack : AppTheme.textGray,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            side: BorderSide(
                              color: isSelected ? AppTheme.primaryAttack : AppTheme.textGray.withOpacity(0.3),
                            ),
                          )
                              .animate()
                              .fadeIn(delay: Duration(milliseconds: 200 + (index * 100)))
                              .slideX(begin: 0.3),
                        );
                      },
                    ),
                  ),
                  
                  // Territory List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      itemCount: filteredTerritories.length,
                      itemBuilder: (context, index) {
                        final territory = filteredTerritories[index];
                        final isUnderAttack = territory.status == TerritoryStatus.underAttack;
                        
                        return TerritoryCard(
                          territory: territory,
                          isOwned: territory.owner == 'You',
                          isUnderAttack: isUnderAttack,
                          onAttack: territory.canBeAttacked ? () => _attackTerritory(territory) : null,
                        )
                            .animate()
                            .fadeIn(
                              delay: Duration(milliseconds: 100 + (index * 50)),
                              duration: const Duration(milliseconds: 400),
                            )
                            .slideX(begin: 0.3);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      
      // Floating Action Button for Quick Attack
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _quickAttack,
        backgroundColor: AppTheme.primaryAttack,
        foregroundColor: AppTheme.textWhite,
        icon: const Icon(Icons.flash_on),
        label: const Text('Quick Attack'),
      )
          .animate()
          .fadeIn(delay: const Duration(milliseconds: 1000))
          .slideY(begin: 1.0),
    );
  }

  void _attackTerritory(Territory territory) {
    showDialog(
      context: context,
      builder: (context) => AttackDialog(territory: territory),
    );
  }

  void _quickAttack() {
    final availableTargets = territories
        .where((t) => t.canBeAttacked && t.owner != 'You')
        .toList();
    
    if (availableTargets.isNotEmpty) {
      final target = availableTargets.first;
      _attackTerritory(target);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No territories available for attack'),
          backgroundColor: AppTheme.dangerOrange,
        ),
      );
    }
  }
}

class AttackDialog extends StatefulWidget {
  final Territory territory;

  const AttackDialog({Key? key, required this.territory}) : super(key: key);

  @override
  State<AttackDialog> createState() => _AttackDialogState();
}

class _AttackDialogState extends State<AttackDialog>
    with TickerProviderStateMixin {
  late AnimationController _attackController;
  late Animation<double> _attackAnimation;
  
  int _attackPower = 0;
  bool _isAttacking = false;

  @override
  void initState() {
    super.initState();
    
    _attackController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _attackAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _attackController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _attackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppTheme.primaryAttack.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.rocket_launch,
                  color: AppTheme.primaryAttack,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attack ${widget.territory.name}',
                        style: AppTextStyles.territoryName,
                      ),
                      Text(
                        'Owner: ${widget.territory.owner ?? 'Unowned'}',
                        style: AppTextStyles.ownerName,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Attack Power Slider
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attack Power: $_attackPower points',
                  style: AppTextStyles.monoNumbers.copyWith(
                    fontSize: 16,
                    color: AppTheme.primaryAttack,
                  ),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _attackPower.toDouble(),
                  min: 0,
                  max: 85, // Mock max attack points
                  divisions: 17,
                  activeColor: AppTheme.primaryAttack,
                  inactiveColor: AppTheme.textGray.withOpacity(0.3),
                  onChanged: _isAttacking ? null : (value) {
                    setState(() {
                      _attackPower = value.round();
                    });
                  },
                ),
                Text(
                  'Damage: ${(_attackPower / 10).floor()} shield hits',
                  style: AppTextStyles.statusText.copyWith(
                    color: AppTheme.textGray,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Attack Animation
            if (_isAttacking)
              Container(
                height: 100,
                child: AnimatedBuilder(
                  animation: _attackAnimation,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Explosion effect
                        Transform.scale(
                          scale: _attackAnimation.value * 2,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryAttack.withOpacity(
                                1.0 - _attackAnimation.value,
                              ),
                            ),
                          ),
                        ),
                        // Missile
                        Transform.translate(
                          offset: Offset(
                            -100 + (200 * _attackAnimation.value),
                            0,
                          ),
                          child: Icon(
                            Icons.rocket,
                            color: AppTheme.primaryAttack,
                            size: 32,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isAttacking ? null : () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: AppTheme.textGray),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isAttacking || _attackPower == 0 ? null : _launchAttack,
                    style: AppButtonStyles.attackButton,
                    child: Text(_isAttacking ? 'Attacking...' : 'Launch Attack'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _launchAttack() {
    setState(() {
      _isAttacking = true;
    });
    
    _attackController.forward().then((_) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attack launched on ${widget.territory.name}!'),
          backgroundColor: AppTheme.primaryAttack,
        ),
      );
    });
  }
}

