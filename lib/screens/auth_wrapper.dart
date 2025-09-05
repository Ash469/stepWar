import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'google_login_screen.dart';
import '../main.dart'; // For MainScreen

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show loading screen while determining auth state
        if (authProvider.authState == AuthState.unknown || authProvider.isLoading) {
          return const LoadingScreen();
        }

        // Show error if authentication failed
        if (authProvider.errorMessage != null && 
            authProvider.authState == AuthState.unauthenticated) {
          return ErrorScreen(
            error: authProvider.errorMessage!,
            onRetry: () {
              // You could trigger a refresh here if needed
            },
          );
        }

        // Route based on authentication state
        switch (authProvider.authState) {
          case AuthState.unauthenticated:
            return const GoogleLoginScreen();
          
          case AuthState.authenticated:
            return const MainScreen();
          
          default:
            return const GoogleLoginScreen();
        }
      },
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.flag,
                size: 64,
                color: AppTheme.successGold,
              ),
              SizedBox(height: 24),
              Text(
                'StepWars',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.successGold,
                ),
              ),
              SizedBox(height: 32),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.successGold),
              ),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  color: AppTheme.textGray,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const ErrorScreen({
    Key? key,
    required this.error,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
                  Icons.error_outline,
                  size: 64,
                  color: AppTheme.primaryAttack,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Oops!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textGray,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successGold,
                    foregroundColor: AppTheme.backgroundDark,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
