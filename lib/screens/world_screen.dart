import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/territory.dart';
import '../models/user.dart';
import '../services/game_manager_service.dart';
import '../services/attack_service.dart';
import '../services/firebase_game_database.dart';
import '../widgets/territory_card.dart';
import 'dart:math' as math;
import 'dart:async';

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
  
  final GameManagerService _gameManager = GameManagerService();
  final FirebaseGameDatabase _firebaseDB = FirebaseGameDatabase();
  List<Territory> _territories = [];
  GameUser? _currentUser;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  StreamSubscription? _territoriesSubscription;
  StreamSubscription? _userSubscription;


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
    
    _initializeGameData();
  }
  
  Future<void> _initializeGameData() async {
    try {
      // Initialize Firebase database
      await _firebaseDB.initialize();
      
      // Initialize game manager
      await _gameManager.initialize();
      
      // Load current user
      _currentUser = _gameManager.currentUser;
      
      // Subscribe to Firestore territory updates (real-time)
      _territoriesSubscription = _firebaseDB.listenToAllTerritories().listen(
        (territories) {
          if (mounted) {
            setState(() {
              _territories = territories;
              _hasError = false;
              _errorMessage = null;
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _hasError = true;
              _errorMessage = 'Failed to load territories: $error';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load territories: $error'),
                backgroundColor: AppTheme.dangerOrange,
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: _retryLoadingTerritories,
                ),
              ),
            );
          }
        },
      );
      
      // Subscribe to user updates from game manager
      _userSubscription = _gameManager.userUpdates.listen((user) {
        if (mounted) {
          setState(() {
            _currentUser = user;
          });
        }
      });
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load game data: $e'),
            backgroundColor: AppTheme.dangerOrange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  

  Future<void> _retryLoadingTerritories() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });
    
    try {
      // Cancel existing subscription
      _territoriesSubscription?.cancel();
      
      // Re-subscribe to territories
      _territoriesSubscription = _firebaseDB.listenToAllTerritories().listen(
        (territories) {
          if (mounted) {
            setState(() {
              _territories = territories;
              _hasError = false;
              _errorMessage = null;
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _hasError = true;
              _errorMessage = 'Failed to load territories: $error';
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to retry loading territories: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _territoriesSubscription?.cancel();
    _userSubscription?.cancel();
    super.dispose();
  }

  List<Territory> get filteredTerritories {
    switch (_selectedFilter) {
      case 'Unowned':
        return _territories.where((t) => t.ownerNickname == null).toList();
      case 'Peaceful':
        return _territories.where((t) => t.status == TerritoryStatus.peaceful).toList();
      case 'Under Attack':
        return _territories.where((t) => t.status == TerritoryStatus.underAttack).toList();
      case 'Cooldown':
        return _territories.where((t) => t.status == TerritoryStatus.cooldown).toList();
      default:
        return _territories;
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
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryAttack),
                      ),
                    )
                  : _hasError
                      ? _buildErrorState()
                      : Column(
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
                          '${_territories.length} territories available for conquest',
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
                        
                        final isOwned = _currentUser != null && territory.ownerId == _currentUser!.id;
                        
                        return TerritoryCard(
                          territory: territory,
                          isOwned: isOwned,
                          isUnderAttack: isUnderAttack,
                          onAttack: territory.canBeAttacked && !isOwned ? () => _attackTerritory(territory) : null,
                          onReinforce: isOwned && territory.currentShield < territory.maxShield ? () => _reinforceTerritory(territory) : null,
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
      
    );
  }

  void _attackTerritory(Territory territory) {
    showDialog(
      context: context,
      builder: (context) => AttackDialog(
        territory: territory,
        gameManager: _gameManager,
        currentUser: _currentUser,
      ),
    );
  }
  
  void _reinforceTerritory(Territory territory) {
    showDialog(
      context: context,
      builder: (context) => ReinforceDialog(
        territory: territory,
        gameManager: _gameManager,
        currentUser: _currentUser,
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.dangerOrange,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Territories',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.dangerOrange,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An unexpected error occurred',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textGray,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _retryLoadingTerritories,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAttack,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class AttackDialog extends StatefulWidget {
  final Territory territory;
  final GameManagerService gameManager;
  final GameUser? currentUser;

  const AttackDialog({
    Key? key,
    required this.territory,
    required this.gameManager,
    required this.currentUser,
  }) : super(key: key);

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
    final maxAttackPoints = widget.currentUser?.attackPoints ?? 0;
    final hasAttackPoints = maxAttackPoints > 0;
    
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
                        'Owner: ${widget.territory.ownerNickname ?? 'Unowned'}',
                        style: AppTextStyles.ownerName,
                      ),
                      Text(
                        'Shield: ${widget.territory.currentShield}/${widget.territory.maxShield}',
                        style: AppTextStyles.statusText,
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
                Text(
                  'Available: $maxAttackPoints points',
                  style: AppTextStyles.statusText.copyWith(
                    color: hasAttackPoints ? AppTheme.textGray : AppTheme.dangerOrange,
                  ),
                ),
                if (!hasAttackPoints)
                  Text(
                    'Walk more to earn attack points!',
                    style: AppTextStyles.statusText.copyWith(
                      color: AppTheme.dangerOrange,
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 8),
                if (hasAttackPoints) 
                  Slider(
                    value: _attackPower.toDouble().clamp(0.0, maxAttackPoints.toDouble()),
                    min: 0.0,
                    max: maxAttackPoints.toDouble(),
                    divisions: maxAttackPoints,
                    activeColor: AppTheme.primaryAttack,
                    inactiveColor: AppTheme.textGray.withOpacity(0.3),
                    onChanged: _isAttacking ? null : (value) {
                      setState(() {
                        _attackPower = value.round().clamp(0, maxAttackPoints);
                      });
                    },
                  )
                else
                  Container(
                    height: 48,
                    child: Slider(
                      value: 0,
                      min: 0,
                      max: 1,
                      activeColor: AppTheme.textGray.withOpacity(0.3),
                      inactiveColor: AppTheme.textGray.withOpacity(0.1),
                      onChanged: null, // Disabled
                    ),
                  ),
                Text(
                  'Damage: ${hasAttackPoints ? (_attackPower / 10).floor() : 0} shield hits',
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

  Future<void> _launchAttack() async {
    setState(() {
      _isAttacking = true;
    });
    
    try {
      final result = await widget.gameManager.launchAttack(
        territoryId: widget.territory.id,
        attackPoints: _attackPower,
      );
      
      _attackController.forward().then((_) {
        Navigator.pop(context);
        
        String message;
        Color backgroundColor;
        
        switch (result) {
          case AttackResult.success:
            message = '🎉 Victory! You captured ${widget.territory.name}!';
            backgroundColor = AppTheme.successGold;
            break;
          case AttackResult.failed:
            message = '💥 Attack failed but damaged ${widget.territory.name}';
            backgroundColor = AppTheme.primaryAttack;
            break;
          case AttackResult.insufficientPoints:
            message = '❌ Not enough attack points';
            backgroundColor = AppTheme.dangerOrange;
            break;
          case AttackResult.dailyLimitReached:
            message = '⏰ Daily attack limit reached';
            backgroundColor = AppTheme.dangerOrange;
            break;
          case AttackResult.territoryNotAttackable:
            message = '⛔ Territory cannot be attacked right now';
            backgroundColor = AppTheme.dangerOrange;
            break;
          case AttackResult.alreadyUnderAttack:
            message = '⚔️ Territory is already under attack';
            backgroundColor = AppTheme.dangerOrange;
            break;
          default:
            message = '❌ Attack failed';
            backgroundColor = AppTheme.dangerOrange;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
          ),
        );
      });
    } catch (e) {
      setState(() {
        _isAttacking = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attack failed: $e'),
          backgroundColor: AppTheme.dangerOrange,
        ),
      );
    }
  }
}

class ReinforceDialog extends StatefulWidget {
  final Territory territory;
  final GameManagerService gameManager;
  final GameUser? currentUser;

  const ReinforceDialog({
    Key? key,
    required this.territory,
    required this.gameManager,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<ReinforceDialog> createState() => _ReinforceDialogState();
}

class _ReinforceDialogState extends State<ReinforceDialog>
    with TickerProviderStateMixin {
  late AnimationController _shieldController;
  late Animation<double> _shieldAnimation;
  
  int _shieldPoints = 0;
  bool _isReinforcing = false;

  @override
  void initState() {
    super.initState();
    
    _shieldController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _shieldAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shieldController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _shieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxAvailableShield = widget.territory.maxShield - widget.territory.currentShield;
    final maxUserPoints = widget.currentUser?.shieldPoints ?? 0;
    final maxPoints = math.min(maxAvailableShield, maxUserPoints);
    
    return Dialog(
      backgroundColor: AppTheme.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppTheme.primaryDefend.withOpacity(0.5),
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
                  Icons.shield,
                  color: AppTheme.primaryDefend,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reinforce ${widget.territory.name}',
                        style: AppTextStyles.territoryName,
                      ),
                      Text(
                        'Shield: ${widget.territory.currentShield}/${widget.territory.maxShield}',
                        style: AppTextStyles.ownerName,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Shield Power Slider
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shield Points: $_shieldPoints points',
                  style: AppTextStyles.monoNumbers.copyWith(
                    fontSize: 16,
                    color: AppTheme.primaryDefend,
                  ),
                ),
                Text(
                  'Available: ${widget.currentUser?.shieldPoints ?? 0} points',
                  style: AppTextStyles.statusText.copyWith(
                    color: AppTheme.textGray,
                  ),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _shieldPoints.toDouble(),
                  min: 0,
                  max: maxPoints > 0 ? maxPoints.toDouble() : 1.0,
                  divisions: maxPoints > 0 ? maxPoints : null,
                  activeColor: AppTheme.primaryDefend,
                  inactiveColor: AppTheme.textGray.withOpacity(0.3),
                  onChanged: _isReinforcing || maxPoints == 0 ? null : (value) {
                    setState(() {
                      _shieldPoints = value.round();
                    });
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Before: ${widget.territory.currentShield}',
                      style: AppTextStyles.statusText.copyWith(
                        color: AppTheme.textGray,
                      ),
                    ),
                    Text(
                      'After: ${widget.territory.currentShield + _shieldPoints}',
                      style: AppTextStyles.monoNumbers.copyWith(
                        fontSize: 14,
                        color: AppTheme.primaryDefend,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Shield Animation
            if (_isReinforcing)
              Container(
                height: 100,
                child: AnimatedBuilder(
                  animation: _shieldAnimation,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Shield pulse effect
                        Transform.scale(
                          scale: 1.0 + (_shieldAnimation.value * 0.3),
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryDefend.withOpacity(
                                0.6 - (_shieldAnimation.value * 0.3),
                              ),
                            ),
                            child: Icon(
                              Icons.shield,
                              color: AppTheme.primaryDefend.withOpacity(
                                1.0 - (_shieldAnimation.value * 0.5),
                              ),
                              size: 36,
                            ),
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
                    onPressed: _isReinforcing ? null : () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: AppTheme.textGray),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isReinforcing || _shieldPoints == 0 || maxPoints == 0 ? null : _reinforce,
                    style: AppButtonStyles.defendButton,
                    child: Text(_isReinforcing ? 'Reinforcing...' : 'Add Shields'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reinforce() async {
    setState(() {
      _isReinforcing = true;
    });
    
    try {
      final success = await widget.gameManager.reinforceTerritory(
        territoryId: widget.territory.id,
        shieldPoints: _shieldPoints,
      );
      
      _shieldController.forward().then((_) {
        Navigator.pop(context);
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🛡️ Reinforced ${widget.territory.name} with $_shieldPoints shield points!'),
              backgroundColor: AppTheme.primaryDefend,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Could not reinforce territory'),
              backgroundColor: AppTheme.dangerOrange,
            ),
          );
        }
      });
    } catch (e) {
      setState(() {
        _isReinforcing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reinforcement failed: $e'),
          backgroundColor: AppTheme.dangerOrange,
        ),
      );
    }
  }
}
