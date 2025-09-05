import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/step_analytics_service.dart';
import 'services/game_manager_service.dart';
import 'services/step_tracking_service.dart';
import 'services/firebase_sync_service.dart';
import 'services/persistence_service.dart';
import 'providers/auth_provider.dart';
import 'providers/game_provider.dart';
import 'theme/app_theme.dart';
import 'screens/my_territory_screen.dart';
import 'screens/world_screen.dart';
import 'screens/auth_wrapper.dart';
import 'screens/profile_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'debug/step_counter_debug.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize persistence service first - this is crucial for data restoration
  final persistenceService = PersistenceService();
  await persistenceService.initialize();
  
  // Record app launch for analytics
  await persistenceService.recordAppLaunch();
  
  if (kDebugMode) {
    print('📦 App persistence initialized');
  }
  
  // Initialize step tracking service immediately when app starts
  final stepCounter = StepTrackingService();
  final success = await stepCounter.initialize();
  if (success) {
    await stepCounter.startTracking();
    await stepCounter.enableNotifications();
    if (kDebugMode) {
      print('🚀 Step tracking service auto-started on app launch with notifications');
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
      ],
      child: MaterialApp(
        title: 'StepWars',
        theme: AppTheme.darkTheme,
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
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

  final StepTrackingService _stepTrackingService = StepTrackingService();
  final StepAnalyticsService _analytics = StepAnalyticsService();
  late Future<bool> _initializationFuture;

  final List<Widget> _screens = [
    const MyTerritoryScreen(),
    const WorldScreen(),
    const ProfileScreen(),
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
    // Since step tracking service is already initialized in main(), 
    // we just need to ensure it's running properly
    bool isInitialized = true;
      
    // Initialize Firebase sync service
    final firebaseSyncService = FirebaseStepSyncService();
    try {
      await firebaseSyncService.initialize();
      if (kDebugMode) {
        print('🔄 Firebase sync service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Firebase sync service failed to initialize: $e');
      }
      // Continue without Firebase sync
    }
    
    if (kDebugMode) {
      print('🚀 Step tracking service initialized and started');
      
      // Log analytics report periodically in debug mode
      Timer.periodic(const Duration(minutes: 5), (timer) {
        final report = _analytics.getReport();
        print('📊 Analytics Report:\n${report.getSummary()}');
      });
    }
    
    return isInitialized;
  }


  @override
  void dispose() {
    _pageController.dispose();
    _fabController.dispose();
    _stepTrackingService.dispose(); // Dispose the step tracking service
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
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, 0.0),
                  radius: 1.5,
                  colors: [
                    AppTheme.backgroundDark,
                    AppTheme.backgroundSecondary,
                    AppTheme.backgroundDark,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.sensors,
                        size: 80,
                        color: AppTheme.successGold,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Permission Required',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textWhite,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'StepWars needs sensor permissions to track your steps accurately.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textGray,
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Permission status check
                      FutureBuilder<Map<String, bool>>(
                        future: _checkPermissionStatuses(),
                        builder: (context, permSnapshot) {
                          if (permSnapshot.connectionState == ConnectionState.waiting) {
                            return const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.successGold),
                            );
                          }
                          
                          final permissions = permSnapshot.data ?? {};
                          final sensorsGranted = permissions['sensors'] ?? false;
                          final activityGranted = permissions['activity'] ?? false;
                          
                          return Column(
                            children: [
                              // Permission status indicators
                              _buildPermissionStatus('Motion & Fitness Sensors', sensorsGranted),
                              const SizedBox(height: 8),
                              _buildPermissionStatus('Activity Recognition', activityGranted),
                              const SizedBox(height: 24),
                              
                              // Action buttons
                              if (!sensorsGranted || !activityGranted) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      setState(() {
                                        _initializationFuture = _initializeAndStartTracking();
                                      });
                                    },
                                    icon: const Icon(Icons.security),
                                    label: const Text('Grant Permissions'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.successGold,
                                      foregroundColor: AppTheme.backgroundDark,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: () => _showPermissionInstructions(context),
                                  icon: const Icon(Icons.help_outline, color: AppTheme.textGray),
                                  label: const Text(
                                    'Need help with permissions?',
                                    style: TextStyle(color: AppTheme.textGray),
                                  ),
                                ),
                              ] else ...[
                                // Permissions are granted but initialization failed
                                const Text(
                                  'Permissions are granted, but step tracking failed to initialize.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.dangerOrange,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _initializationFuture = _initializeAndStartTracking();
                                      });
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Try Again'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryDefend,
                                      foregroundColor: AppTheme.textWhite,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
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
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.person, 2),
              activeIcon: _buildNavIcon(Icons.person, 2, isActive: true),
              label: 'Profile',
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

  /// Check current permission statuses
  Future<Map<String, bool>> _checkPermissionStatuses() async {
    final sensorsStatus = await Permission.sensors.status;
    final activityStatus = await Permission.activityRecognition.status;
    
    if (kDebugMode) {
      print('🔍 Current permission statuses:');
      print('  Sensors: $sensorsStatus');
      print('  Activity Recognition: $activityStatus');
    }
    
    return {
      'sensors': sensorsStatus == PermissionStatus.granted,
      'activity': activityStatus == PermissionStatus.granted,
    };
  }

  /// Build permission status indicator
  Widget _buildPermissionStatus(String label, bool granted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: granted 
            ? AppTheme.successGreen.withOpacity(0.1)
            : AppTheme.dangerOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: granted 
              ? AppTheme.successGreen.withOpacity(0.3)
              : AppTheme.dangerOrange.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.cancel,
            color: granted ? AppTheme.successGreen : AppTheme.dangerOrange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: granted ? AppTheme.successGreen : AppTheme.dangerOrange,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            granted ? 'Granted' : 'Required',
            style: TextStyle(
              color: granted ? AppTheme.successGreen : AppTheme.dangerOrange,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Show permission instructions dialog
  void _showPermissionInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundSecondary,
        title: const Text(
          'Permission Setup Help',
          style: TextStyle(color: AppTheme.successGold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'StepWars needs the following permissions to work properly:',
                style: TextStyle(color: AppTheme.textWhite),
              ),
              const SizedBox(height: 16),
              _buildInstructionItem(
                '🏃‍♂️',
                'Motion & Fitness Sensors',
                'Required to detect your steps using device sensors.',
              ),
              const SizedBox(height: 12),
              _buildInstructionItem(
                '🚶‍♀️',
                'Activity Recognition',
                'Helps distinguish walking from other activities for more accurate counting.',
              ),
              const SizedBox(height: 20),
              const Text(
                'If permissions were denied permanently:',
                style: TextStyle(
                  color: AppTheme.textWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Go to device Settings\n2. Find StepWars app\n3. Enable Motion & Fitness permissions\n4. Return to the app',
                style: TextStyle(color: AppTheme.textGray),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Got it',
              style: TextStyle(color: AppTheme.successGold),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGold,
              foregroundColor: AppTheme.backgroundDark,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Build instruction item widget
  Widget _buildInstructionItem(String emoji, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: AppTheme.textGray,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
