import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'screens/loading_screen.dart';
import 'theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/active_battle_service.dart';
import 'services/notification_service.dart';
import 'package:clarity_flutter/clarity_flutter.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // This handler needs to initialize Firebase itself to work in the background.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print("Handling a background message: ${message.messageId}");

  // It's safe to create an instance here for background processing.
  final NotificationService notificationService = NotificationService();
  await notificationService.initialize();
  notificationService.showLocalNotification(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final config = ClarityConfig(
      projectId: "ttsnh3p3bl",
      logLevel: LogLevel
          .None // Note: Use "LogLevel.Verbose" value while testing to debug initialization issues.
      );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    ClarityWidget(
     clarityConfig: config,
      app: MultiProvider(
        providers: [
          Provider<AuthService>(create: (_) => AuthService()),
          ChangeNotifierProvider<ActiveBattleService>(
            create: (_) => ActiveBattleService(),
          ),
        ],
        child: const MyApp(),
      ),
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
