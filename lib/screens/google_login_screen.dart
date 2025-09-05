import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class GoogleLoginScreen extends StatefulWidget {
  const GoogleLoginScreen({Key? key}) : super(key: key);

  @override
  State<GoogleLoginScreen> createState() => _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late Animation<double> _backgroundAnimation;

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
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.signInWithGoogle();
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
                colors: [
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
                        Icon(
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
                            'Sign In to Play',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 24),
                          
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, child) {
                              return ElevatedButton.icon(
                                onPressed: authProvider.isLoading ? null : _handleGoogleSignIn,
                                icon: authProvider.isLoading
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
                                    : Image.asset(
                                        'assets/images/google_logo.png',
                                        width: 20,
                                        height: 20,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(
                                            Icons.account_circle,
                                            size: 20,
                                            color: AppTheme.backgroundDark,
                                          );
                                        },
                                      ),
                                label: Text(
                                  authProvider.isLoading 
                                      ? 'Signing in...' 
                                      : 'Continue with Google',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.successGold,
                                  foregroundColor: AppTheme.backgroundDark,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                ),
                              );
                            },
                          ),
                          
                          // Show error message if any
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, child) {
                              if (authProvider.errorMessage != null) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 16.0),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryAttack.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppTheme.primaryAttack.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          color: AppTheme.primaryAttack,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            authProvider.errorMessage!,
                                            style: const TextStyle(
                                              color: AppTheme.primaryAttack,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
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
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppTheme.primaryAttack,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'How it Works',
                                style: TextStyle(
                                  color: AppTheme.primaryAttack,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
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
                    
                    const SizedBox(height: 24),
                    
                    // Privacy Notice
                    Text(
                      'By continuing, you agree to our Terms of Service and Privacy Policy. '
                      'We use your Google name and profile photo for your game profile.',
                      style: TextStyle(
                        color: AppTheme.textGray.withOpacity(0.8),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: const Duration(milliseconds: 1200)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
