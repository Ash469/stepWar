import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stepwars_app/screens/main_screen.dart';
import '../services/auth_service.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  final AuthService _authService = AuthService();

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
    } else {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

      if (hasSeenOnboarding) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
    }
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
              valueColor: AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 252, 235, 2)),
            ),
          ],
        ),
      ),
    );
  }
}
