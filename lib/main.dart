import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/loading_screen.dart';
import 'theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/active_battle_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
   runApp(
    // 2. Use MultiProvider to provide multiple services
    MultiProvider(
      providers: [
        // Provider for your plain AuthService class
        Provider<AuthService>(create: (_) => AuthService()),
        
        // ChangeNotifierProvider for your stateful ActiveBattleService
        ChangeNotifierProvider<ActiveBattleService>(create: (_) => ActiveBattleService()),
      ],
      child: const MyApp(),
    ),
   );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StepWars',
      theme: AppThemes.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const LoadingScreen(),
    );
  }
}
