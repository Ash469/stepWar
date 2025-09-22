import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/game_manager_service.dart';
import '../services/auth_service.dart';
import 'my_territory_screen.dart';
import 'world_screen.dart';

class UserLoginScreen extends StatefulWidget {
  const UserLoginScreen({Key? key}) : super(key: key);

  @override
  State<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _nicknameController = TextEditingController();
  final GameManagerService _gameManager = GameManagerService();
  final AuthService _authService = AuthService();
  
  late AnimationController _backgroundController;
  late Animation<double> _backgroundAnimation;
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 15),
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
    
    // Initialize game manager
    _initializeGameManager();
  }

  Future<void> _initializeGameManager() async {
    await _gameManager.initialize();
    
    // Check if user is already logged in with stored Firestore user ID
    await _checkExistingLogin();
  }

  Future<void> _checkExistingLogin() async {
    try {
      final storedUserId = await _authService.getStoredFirestoreUserId();
      final isLoggedIn = await _authService.getStoredLoginState();
      
      if (isLoggedIn && storedUserId != null) {
        print('🔄 Found stored Firestore user ID: $storedUserId');
        print('🎯 Attempting automatic login...');
        
        final success = await _gameManager.loginUserWithFirebaseId(storedUserId);
        if (success && mounted) {
          print('✅ Automatic login successful!');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const GameMainScreen(),
            ),
          );
        } else {
          print('❌ Automatic login failed, showing login screen');
        }
      }
    } catch (e) {
      print('❌ Error checking existing login: $e');
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _nicknameController.dispose();
    super.dispose();
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
                  0.3 * (2 * _backgroundAnimation.value - 1),
                  0.2 * (2 * _backgroundAnimation.value - 1),
                ),
                radius: 1.5,
                colors: const [
                  AppTheme.backgroundDark,
                  AppTheme.backgroundSecondary,
                  AppTheme.backgroundDark,
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo/Title Section
                    Column(
                      children: [
                        const Icon(
                          Icons.flag,
                          size: 80,
                          color: AppTheme.successGold,
                        ).animate().fadeIn(duration: const Duration(milliseconds: 800)).scale(),
                        
                        const SizedBox(height: 24),
                        
                        Text(
                          'StepWars',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successGold,
                          ),
                        ).animate().fadeIn(delay: const Duration(milliseconds: 400)).slideY(begin: 0.3),
                        
                        const SizedBox(height: 12),
                        
                        Text(
                          'Conquer territories with every step',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.textGray,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: const Duration(milliseconds: 600)).slideY(begin: 0.3),
                      ],
                    ),
                    
                    const SizedBox(height: 64),
                    
                    // Login Form
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundSecondary.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.successGold.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Choose Your Warrior Name',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 24),
                          
                          TextField(
                            controller: _nicknameController,
                            enabled: !_isLoading,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Enter your nickname',
                              hintStyle: TextStyle(color: AppTheme.textGray),
                              prefixIcon: const Icon(
                                Icons.person,
                                color: AppTheme.successGold,
                              ),
                              filled: true,
                              fillColor: AppTheme.backgroundDark.withOpacity(0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppTheme.successGold.withOpacity(0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppTheme.successGold.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppTheme.successGold,
                                  width: 2,
                                ),
                              ),
                              errorText: _errorMessage,
                            ),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _handleLogin(),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successGold,
                              foregroundColor: AppTheme.backgroundDark,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppTheme.backgroundDark,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Enter the Battle',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Google Sign-In Button
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _handleGoogleSignIn,
                            icon: const Icon(Icons.login, size: 20),
                            label: const Text('Sign in with Google'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryAttack,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: const Duration(milliseconds: 800)).slideY(begin: 0.5),
                    
                    const SizedBox(height: 32),
                    
                    // Game Rules Info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundSecondary.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryAttack.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppTheme.primaryAttack,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'How it Works',
                                style: TextStyle(
                                  color: AppTheme.primaryAttack,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            '• Walk to earn attack and shield points\n'
                            '• Capture territories from other players\n'
                            '• Defend your territories from attacks\n'
                            '• 3 attacks per day limit',
                            style: TextStyle(
                              color: AppTheme.textGray,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: const Duration(milliseconds: 1000)).slideY(begin: 0.3),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleLogin() async {
    final nickname = _nicknameController.text.trim();
    
    if (nickname.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a nickname';
      });
      return;
    }

    if (nickname.length < 3) {
      setState(() {
        _errorMessage = 'Nickname must be at least 3 characters';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _gameManager.loginUser(nickname);
      
      if (success) {
        // Navigate to main game screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const GameMainScreen(),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Nickname already taken. Choose a different one.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create account. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔄 Starting Google Sign-In...');
      final userCredential = await _authService.signInWithGoogle();
      
      if (userCredential?.user != null) {
        final firebaseUserId = userCredential!.user!.uid;
        print('✅ Google Sign-In successful: $firebaseUserId');
        
        // Login to game with Firebase user ID
        final success = await _gameManager.loginUserWithFirebaseId(firebaseUserId);
        
        if (success && mounted) {
          print('✅ Game login successful!');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const GameMainScreen(),
            ),
          );
        } else {
          setState(() {
            _errorMessage = 'Failed to login to game. Please try again.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Google Sign-In was cancelled or failed.';
        });
      }
    } catch (e) {
      print('❌ Google Sign-In error: $e');
      setState(() {
        _errorMessage = 'Google Sign-In failed. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

class GameMainScreen extends StatefulWidget {
  const GameMainScreen({Key? key}) : super(key: key);

  @override
  State<GameMainScreen> createState() => _GameMainScreenState();
}

class _GameMainScreenState extends State<GameMainScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;


  final List<Widget> _screens = [
    const MyTerritoryScreen(),
    const WorldScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fabAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeInOut,
    ));
    
    _fabController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    
    // FAB animation
    _fabController.reset();
    _fabController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _screens,
      ),
      
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.backgroundDark.withOpacity(0.8),
              AppTheme.backgroundDark,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryAttack.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.successGold,
          unselectedItemColor: AppTheme.textGray,
          items: [
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.home, 0),
              activeIcon: _buildNavIcon(Icons.home, 0, isActive: true),
              label: 'My Territory',
            ),
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.public, 1),
              activeIcon: _buildNavIcon(Icons.public, 1, isActive: true),
              label: 'World',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, int index, {bool isActive = false}) {
    return AnimatedBuilder(
      animation: _fabAnimation,
      builder: (context, child) {
        final isCurrentTab = _currentIndex == index;
        final scale = isCurrentTab && isActive ? 
            1.0 + (0.2 * _fabAnimation.value) : 1.0;
        
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? 
                  AppTheme.successGold.withOpacity(0.2) : 
                  Colors.transparent,
              border: isActive ? Border.all(
                color: AppTheme.successGold.withOpacity(0.5),
                width: 2,
              ) : null,
            ),
            child: Icon(
              icon,
              size: 24,
              color: isActive ? AppTheme.successGold : AppTheme.textGray,
            ),
          ),
        );
      },
    );
  }
}
