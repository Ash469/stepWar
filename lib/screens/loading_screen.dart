import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/play_games_service.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import 'profile_completion_screen.dart';
import 'main_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  final AuthService _authService = AuthService();
  final PlayGamesService _playGamesService = PlayGamesService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final bool loggedIn = await _authService.isLoggedIn();

    if (loggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
      return;
    }

    if (Platform.isAndroid) {
      print('[LoadingScreen] Attempting automatic Play Games sign-in...');
      try {
        final user = await _playGamesService.attemptSilentSignIn();

        if (user != null && mounted) {
          print('[LoadingScreen] ✅ Automatic Play Games sign-in successful!');

          final isNew = await _authService.isNewUser(user.uid);

          if (!mounted) return;

          if (isNew) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ProfileCompletionScreen(user: user),
              ),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MainScreen()),
            );
          }
          return;
        } else {
          print(
              '[LoadingScreen] Automatic Play Games sign-in not available, showing manual login options');
        }
      } catch (e) {
        print('[LoadingScreen] Play Games automatic sign-in failed: $e');
      }
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    if (!mounted) return;

    // V1.5: Skip pre-login onboarding, tutorial is now accessible via info icon on home screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(212, 0, 0, 0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/app_logo.png',
              width: 240,
              height: 240,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Icon(
                    Icons.directions_walk,
                    size: 80,
                    color: Colors.black,
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                  Color.fromARGB(255, 252, 235, 2)),
            ),
          ],
        ),
      ),
    );
  }
}
