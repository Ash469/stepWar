import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'screens/loading_screen.dart';
import 'const/app_theme.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/active_battle_service.dart';
import 'services/notification_service.dart';
import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print("Handling a background message: ${message.messageId}");

  final NotificationService notificationService = NotificationService();
  await notificationService.initialize();
  notificationService.showLocalNotification(message);
}

final Map<String, dynamic> remoteConfigDefaults = {
  'backend_url': 'http://stepwars.ap-south-1.elasticbeanstalk.com',
  'battle_time_minutes': 10, 
  'multiplier_3x_price': 300,
  'multiplier_2x_price': 200,
  'multiplier_1_5x_price': 100,
  'ko_diff': 200,
  'draw_diff': 50,
  'step_save_debounce_minutes': 15, 
  'bronze_box_price': 5000,
  'silver_box_price': 10000,
  'gold_box_price': 20000,
};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
   FlutterForegroundTask.initCommunicationPort();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final remoteConfig = FirebaseRemoteConfig.instance;

  try {
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: const Duration(seconds: 10), 
    ));
    await remoteConfig.setDefaults(remoteConfigDefaults);
    final bool activated = await remoteConfig.fetchAndActivate();
    if (activated) {
      print('✅ Remote Config: Successfully fetched AND activated new values.');
    } else {
      print('ℹ️ Remote Config: Fetch successful, but no new values were activated (fetched values match current).');
    }
  } catch (e) {
    print('❌ Remote Config: Error during initialization or fetch/activate: $e');
  }

  final config = ClarityConfig(
      projectId: "ttsnh3p3bl",
      logLevel: LogLevel
          .None 
      );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("f3677a87-be26-44a2-9419-1d6241842d22");
  OneSignal.Notifications.requestPermission(false);

  runApp(
    ClarityWidget(
     clarityConfig: config,
      app: MultiProvider(
        providers: [
          Provider<AuthService>(create: (_) => AuthService()),
          ChangeNotifierProvider<ActiveBattleService>(
            create: (_) => ActiveBattleService(),
          ),
          Provider<FirebaseRemoteConfig>(create: (_) => remoteConfig),
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
