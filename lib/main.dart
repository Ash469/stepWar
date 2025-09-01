import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/production_step_counter.dart'; // Import the production service
import 'services/step_analytics_service.dart';
import 'services/game_manager_service.dart';
import 'theme/app_theme.dart';
import 'screens/my_territory_screen.dart';
import 'screens/world_screen.dart';
import 'screens/user_login_screen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize step counter immediately when app starts
  final stepCounter = ProductionStepCounter();
  final success = await stepCounter.initialize();
  if (success) {
    await stepCounter.startTracking();
    if (kDebugMode) {
      print('🚀 Step counter auto-started on app launch');
    }
  }
  
  // Initialize game manager
  final gameManager = GameManagerService();
  await gameManager.initialize();
  
  runApp(const StepWarsApp());
}

class StepWarsApp extends StatelessWidget {
  const StepWarsApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StepWars',
      theme: AppTheme.darkTheme,
      home: const UserLoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;

  final ProductionStepCounter _stepCounter = ProductionStepCounter();
  final StepAnalyticsService _analytics = StepAnalyticsService();
  late Future<bool> _initializationFuture;

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

    // Initialize analytics
    _analytics.initialize();
    
    // Initialize the production step counter and start tracking
    _initializationFuture = _initializeAndStartTracking();
  }

  Future<bool> _initializeAndStartTracking() async {
    bool isInitialized = await _stepCounter.initialize();
    if (isInitialized) {
      await _stepCounter.startTracking();
      
      if (kDebugMode) {
        print('🚀 Production step counter initialized and started');
        
        // Log analytics report periodically in debug mode
        Timer.periodic(const Duration(minutes: 5), (timer) {
          final report = _analytics.getReport();
          print('📊 Analytics Report:\n${report.getSummary()}');
        });
      }
    }
    return isInitialized;
  }


  @override
  void dispose() {
    _pageController.dispose();
    _fabController.dispose();
    _stepCounter.dispose(); // Dispose the production step counter
    _analytics.dispose(); // Dispose analytics
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
    
    // Haptic feedback
    HapticFeedback.lightImpact();
    
    // FAB animation
    _fabController.reset();
    _fabController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<bool>(
        future: _initializationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == false) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Permissions Required',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This app needs sensor and activity recognition permissions to count your steps.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _initializationFuture = _initializeAndStartTracking();
                        });
                      },
                      child: const Text('Grant Permissions'),
                    )
                  ],
                ),
              ),
            );
          }

          return PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: _screens,
          );
        },
      ),
      
      bottomNavigationBar: Container(
        // ... (rest of your BottomNavigationBar code)
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
          selectedLabelStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
          ),
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
    // ... (rest of your _buildNavIcon code)
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