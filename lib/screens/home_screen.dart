// ignore_for_file: unused_import, unused_field
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stepwars_app/services/active_battle_service.dart';
import 'package:stepwars_app/services/bot_service.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/game_service.dart';
import '../services/step_counting.dart';
import '../services/permission_service.dart';
import '../widget/footer.dart';
import '../widgets/permission_bottom_sheet.dart';
import 'battle_screen.dart';
import 'waiting_for_friend_screen.dart';
import 'matchmaking_screen.dart';
import '../widget/game_rules.dart';
import '../services/notification_service.dart';
import '../services/mystery_box_service.dart';
import 'kingdom_screen.dart' show KingdomItem;
import '../widget/mystery_box_section.dart';
import '../widget/reward_dialog.dart';
import '../widget/string_extension.dart';
import '../widget/home/home_header.dart';
import '../widget/home/step_counter_card.dart';
import '../widget/home/scorecard_section.dart';
import '../widget/home/battle_section.dart';
import '../widget/home/rewards_section.dart';
import '../widget/home/section_title.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../services/step_task_handler.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import '../providers/step_provider.dart';
import 'package:showcaseview/showcaseview.dart';
import 'google_fit_stats_screen.dart';
import '../const/string.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  final GlobalKey onlineBattleKey;
  final GlobalKey friendBattleKey;
  // final GlobalKey googleFitKey;
  final GlobalKey stepCountKey;

  const HomeScreen({
    super.key,
    required this.onlineBattleKey,
    required this.friendBattleKey,
    // required this.googleFitKey,
    required this.stepCountKey,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final AuthService _authService = AuthService();
  final HealthService _healthService = HealthService();
  final GameService _gameService = GameService();
  final BotService _botService = BotService();
  final NotificationService _notificationService = NotificationService();
  final MysteryBoxService _mysteryBoxService = MysteryBoxService();

  UserModel? _user;
  UserModel? _opponentProfile;
  bool _isLoading = true;
  StreamSubscription? _stepSubscription;
  Timer? _debounce;
  final bool _isCreatingBotGame = false;
  bool _isHandlingFriendGame = false;
  // _stepsToShow removed - now using StepProvider
  bool _isFetchingOpponent = false;
  final bool _isCreatingGame = false;
  bool _isOpeningBronzeBox = false;
  bool _isOpeningSilverBox = false;
  bool _isOpeningGoldBox = false;
  Timer? _boxTimer;
  Duration _bronzeTimeLeft = Duration.zero;
  Duration _silverTimeLeft = Duration.zero;
  Duration _goldTimeLeft = Duration.zero;
  KingdomItem? _latestReward;
  bool _isLoadingData = false;
  bool _isPedometerPermissionGranted = true;
  bool _isBatteryOptimizationEnabled = true;
  bool _offsetInitializationDone = false;
  DateTime? _lastPausedTime;
  DateTime _lastOpponentFetchTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _offsetInitializationDone = false;
    _debounce?.cancel();
    _stepSubscription?.cancel();

    _loadData(isInitialLoad: true);
    WidgetsBinding.instance.addObserver(this);
    _startBoxTimers();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _handleNotifications();
      _initService();
      await _startService();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _checkForOngoingBattle();
      });
    });
  }

  Future<void> _checkForOngoingBattle() async {
    if (!mounted) return;
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final battleService = context.read<ActiveBattleService>();

      // 1. Check in-memory state first (normal flow)
      if (battleService.isBattleActive &&
          battleService.isWaitingForFriend &&
          _user != null) {
        final gameId = battleService.currentGame?.gameId;
        if (gameId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) =>
                      WaitingForFriendScreen(gameId: gameId, user: _user!),
                ),
                (route) => route.isFirst,
              );
            }
          });
          return;
        }
      }

      // 2. Check persisted state (recovery flow)
      final prefs = await SharedPreferences.getInstance();
      final persistedGameId = prefs.getString('active_battle_id');

      if (persistedGameId != null &&
          _user != null &&
          !battleService.isBattleActive) {
        await battleService.recoverAndEndBattle(persistedGameId, _user!);
      }
    } catch (e) {
      print("Error checking for ongoing battle: $e");
    }
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    _debounce?.cancel();
    _healthService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _boxTimer?.cancel();
    super.dispose();
  }

  void _startBoxTimers() {
    _boxTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _user?.mysteryBoxLastOpened == null) return;

      if (mounted) {
        setState(() {
          _bronzeTimeLeft = _calculateTimeLeft('bronze');
          _silverTimeLeft = _calculateTimeLeft('silver');
          _goldTimeLeft = _calculateTimeLeft('gold');
        });
      }
    });
  }

  Duration _calculateTimeLeft(String boxType) {
    final lastOpenedString = _user?.mysteryBoxLastOpened?[boxType];
    if (lastOpenedString == null) return Duration.zero;

    try {
      final lastOpenedDate = DateTime.parse(lastOpenedString).toLocal();
      final now = DateTime.now();
      final nextAvailableTime = lastOpenedDate.add(const Duration(hours: 24));

      if (now.isBefore(nextAvailableTime)) {
        return nextAvailableTime.difference(now);
      }
    } catch (e) {
      print("Error parsing mystery box date for $boxType: $e");
    }
    return Duration.zero;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _lastPausedTime = DateTime.now();
      print("App is pausing. Forcing final step save.");

      // Note: Battle ending on app termination is handled by ActiveBattleService
      // We should NOT end battles here when the app goes to background

      _debounce?.cancel();
      _stepSubscription?.cancel(); // Add this
      if (mounted) {
        final currentSteps = context.read<StepProvider>().currentSteps;
        final dbSteps = _user?.todaysStepCount ?? 0;
      }
    }
    if (state == AppLifecycleState.resumed) {
      print("App resumed. Cancelling pending saves & triggering data load.");
      _debounce?.cancel();
      _stepSubscription?.cancel();
      final bool wasPausedLong = _lastPausedTime != null &&
          DateTime.now().difference(_lastPausedTime!).inMinutes >= 1;
      if (wasPausedLong || _user == null) {
        print(
          "App was paused for > 1 min OR user is null. Triggering data load.",
        );
        if (mounted) {
          _loadData();
        }
      } else {
        print("App resumed from brief pause. Skipping full data load.");
        _lastPausedTime = null; // Clear the paused time
      }
    }
  }

  Future<void> _showPermissionSheet() async {
    await PermissionBottomSheet.show(
      context,
      showCloseButton: true,
      onAllGranted: () {
        _loadPermissionStatus();
      },
    );
    await _loadPermissionStatus();
  }

  Future<void> _loadPermissionStatus() async {
    final activityStatus = await Permission.activityRecognition.status;
    final batteryOptimization =
        await FlutterForegroundTask.isIgnoringBatteryOptimizations;

    if (mounted) {
      setState(() {
        _isPedometerPermissionGranted = activityStatus.isGranted;
        _isBatteryOptimizationEnabled = batteryOptimization;
      });
      if (activityStatus.isGranted) {
        _initStepCounter(_user);
      }
    }
  }

  void _initService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'step_counter_channel',
        channelName: 'Step Counter',
        channelDescription: 'Shows your current step count.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(10000),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<ServiceRequestResult> _startService() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FlutterForegroundTask.saveData(
          key: 'userId', value: currentUser.uid);
      await FlutterForegroundTask.saveData(
        key: 'backendUrl',
        value: getBackendUrl(),
      );

      // Get sync interval from Remote Config
      final remoteConfig = FirebaseRemoteConfig.instance;
      final int syncIntervalMinutes =
          remoteConfig.getInt('step_save_debounce_minutes');
      await FlutterForegroundTask.saveData(
        key: 'syncInterval',
        value: syncIntervalMinutes > 0 ? syncIntervalMinutes : 15,
      );

      // ✅ Save DB steps so service can use it as baseline
      final int dbSteps = _user?.todaysStepCount ?? 0;
      await FlutterForegroundTask.saveData(
        key: 'initialDbSteps',
        value: dbSteps,
      );

      print(
        "StepTaskHandler: Saved userId, backendUrl, and syncInterval ($syncIntervalMinutes min) to background task data",
      );
    }
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    } else {
      return FlutterForegroundTask.startService(
        serviceId: 101,
        notificationTitle: 'Step Counter Running',
        notificationText: 'Steps: 0',
        notificationInitialRoute: '/',
        callback: startCallback,
      );
    }
  }

  Future<void> _openMysteryBox(String boxType, int price) async {
    if (_user == null || _isLoadingData) return;
    final canAfford = (_user!.coins ?? 0) >= price;
    if (!canAfford) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You don't have enough coins!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final confirmed = await _showConfirmationDialog(boxType, price);
    if (confirmed != true) return;
    setState(() {
      if (boxType == 'bronze') _isOpeningBronzeBox = true;
      if (boxType == 'silver') _isOpeningSilverBox = true;
      if (boxType == 'gold') _isOpeningGoldBox = true;
    });
    try {
      final reward = await _mysteryBoxService.openMysteryBox(
        _user!.userId,
        boxType,
      );
      final newCoinBalance = reward['newCoinBalance'] as int?;
      if (newCoinBalance != null && mounted) {
        setState(() {
          final updatedLastOpened = Map<String, String>.from(
            _user!.mysteryBoxLastOpened ?? {},
          );
          updatedLastOpened[boxType] = DateTime.now().toIso8601String();
          _user = _user!.copyWith(
            coins: newCoinBalance,
            mysteryBoxLastOpened: updatedLastOpened,
          );
        });
        _authService.saveUserSession(_user!);
      }
      _showRewardDialog(reward);
      _loadData(forceRefresh: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst("Exception: ", "")),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (boxType == 'bronze') _isOpeningBronzeBox = false;
          if (boxType == 'silver') _isOpeningSilverBox = false;
          if (boxType == 'gold') _isOpeningGoldBox = false;
        });
      }
    }
  }

  Future<bool?> _showConfirmationDialog(String boxType, int price) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: const Text(
          'Confirm Purchase',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Open the ${boxType.capitalize()} box for $price coins?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Confirm',
              style: TextStyle(color: Color(0xFFFFC107)),
            ),
          ),
        ],
      ),
    );
  }

  void _showRewardDialog(Map<String, dynamic> reward) {
    Widget rewardContent;
    String titleText;
    String subtitleText = "";

    switch (reward['type']) {
      case 'coins':
        titleText = "${reward['amount']} Coins!";
        rewardContent = Image.asset('assets/images/coin_icon.png', height: 80);
        break;
      case 'multiplier':
        titleText = "Multiplier Token!";
        subtitleText = "You got a ${reward['multiplierType']} token";
        rewardContent = Text(
          reward['multiplierType'].toString().replaceAll('_', '.'),
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        );
        break;
      case 'collectible':
        var itemData = reward['item'];
        // Handle case where item might be a JSON string (common in some parts of the app)
        if (itemData is String) {
          try {
            itemData = jsonDecode(itemData);
          } catch (e) {
            print("StepWars: Error decoding reward item JSON: $e");
          }
        }

        final Map<String, dynamic> item =
            (itemData is Map) ? Map<String, dynamic>.from(itemData) : {};

        titleText = "New Collectible!";
        subtitleText = item['name'] ?? 'A new item';
        String? imagePath = item['imagePath'];

        rewardContent = imagePath != null
            ? (imagePath.startsWith('http')
                ? CachedNetworkImage(
                    imageUrl: imagePath,
                    height: 80,
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.shield, size: 80, color: Colors.black),
                  )
                : Image.asset(
                    imagePath,
                    height: 80,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.shield, size: 80, color: Colors.black),
                  ))
            : const Icon(Icons.shield, size: 80, color: Colors.black);
        break;
      default:
        titleText = "Special Reward!";
        rewardContent = const Icon(Icons.star, size: 80, color: Colors.black);
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => RewardDialog(
          title: titleText,
          subtitle: subtitleText,
          rewardContent: rewardContent,
        ),
      );
    }
  }

  Future<void> _handleNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final hasRegisteredToken = prefs.getBool('hasRegisteredFcmToken') ?? false;

    if (hasRegisteredToken) {
      return;
    }

    final user = _authService.currentUser;
    if (user != null) {
      await _notificationService.initialize();
      final token = await _notificationService.getFcmToken();
      if (token != null) {
        final success = await _notificationService.registerTokenWithBackend(
          user.uid,
          token,
        );
        if (success) {
          await prefs.setBool('hasRegisteredFcmToken', true);
        }
      }
    }
  }

  Future<void> _fetchOpponentProfile(ActiveBattleService battleService) async {
    if (_isFetchingOpponent ||
        _opponentProfile != null ||
        battleService.currentGame == null ||
        DateTime.now().difference(_lastOpponentFetchTime).inSeconds < 10) {
      return;
    }
    if (mounted) setState(() => _isFetchingOpponent = true);
    final game = battleService.currentGame!;
    if (_user == null) {
      if (mounted) setState(() => _isFetchingOpponent = false);
      print("Cannot fetch opponent, current user data is null.");
      return;
    }
    final isUserPlayer1 = game.player1Id == _user!.userId;
    final opponentId = isUserPlayer1 ? game.player2Id : game.player1Id;
    UserModel? opponent;
    if (opponentId != null && opponentId.isNotEmpty) {
      if (opponentId.startsWith('bot_')) {
        final botType = _botService.getBotTypeFromId(opponentId);
        if (botType != null) {
          opponent = UserModel(
            userId: opponentId,
            username: _botService.getBotNameFromId(opponentId),
            profileImageUrl: _botService.getBotImagePath(botType),
          );
        }
      } else {
        opponent = await _authService.getUserProfile(opponentId);
      }
    }
    if (mounted) {
      setState(() {
        if (opponent != null) {
          _opponentProfile = opponent;
        }
        _isFetchingOpponent = false;
      });
    }
  }

  void _setLatestRewardFromData(Map<String, dynamic> rawRewardsMap) {
    if (!mounted) return;
    KingdomItem? latest;
    rawRewardsMap.forEach((key, value) {
      if (value is List && value.isNotEmpty) {
        final lastItem = value.last;
        if (lastItem is Map<String, dynamic>) {
          try {
            final item = KingdomItem.fromJson(lastItem);
            latest ??= item;
          } catch (e) {
            print("Error parsing reward item: $e, item data: $lastItem");
          }
        }
      }
    });

    if (mounted) {
      setState(() {
        _latestReward = latest;
      });
    }
  }

  Future<UserModel?> _loadUserFromCache(SharedPreferences prefs) async {
    final cachedProfile = prefs.getString('userProfile');
    if (cachedProfile != null) {
      try {
        final user = UserModel.fromJson(jsonDecode(cachedProfile));
        print("[Cache Load] Loaded user from SharedPreferences cache.");
        return user;
      } catch (e) {
        print("[Cache Load] Error parsing user cache: $e");
        await prefs.remove('userProfile'); // Clear corrupted cache
        return null;
      }
    }
    print("[Cache Load] No user profile found in SharedPreferences cache.");
    return null;
  }

  Map<String, dynamic>? _loadRewardsFromCacheSync(SharedPreferences prefs) {
    final cachedRewardsString = prefs.getString('userRewardsCache');
    if (cachedRewardsString != null) {
      try {
        return jsonDecode(cachedRewardsString) as Map<String, dynamic>;
      } catch (e) {
        print("[Cache Load] Error parsing rewards cache: $e");
        prefs.remove('userRewardsCache'); // Clear corrupted cache
        return null;
      }
    }
    print("[Cache Load] No rewards found in SharedPreferences cache.");
    return null;
  }

  Future<void> _fetchFreshDataInBackground(
    SharedPreferences prefs,
    User? currentUser,
  ) async {
    if (currentUser == null || !mounted) return;

    const refreshThreshold = Duration(minutes: 15);
    final lastRefreshString = prefs.getString('lastProfileRefreshTimestamp');
    bool shouldFetch = false;
    if (lastRefreshString == null) {
      shouldFetch = true;
    } else {
      final lastRefreshTime = DateTime.tryParse(lastRefreshString);
      if (lastRefreshTime != null &&
          DateTime.now().difference(lastRefreshTime) > refreshThreshold) {
        shouldFetch = true;
      }
    }

    if (!shouldFetch) {
      print("[Background Fetch] Cache is recent, skipping background fetch.");
      return;
    }

    print("[Background Fetch] Fetching fresh data in background...");
    try {
      final results = await Future.wait([
        _authService.refreshUserProfile(currentUser.uid),
        _authService.getUserRewards(currentUser.uid),
      ]);

      final serverUser = results[0] as UserModel?;
      final serverRewards = results[1] as Map<String, dynamic>?;

      if (serverUser != null && mounted) {
        await prefs.setString(
          'lastProfileRefreshTimestamp',
          DateTime.now().toIso8601String(),
        );

        if (serverRewards != null) {
          await prefs.setString('userRewardsCache', jsonEncode(serverRewards));
        }
        setState(() {
          _user = serverUser;
          if (serverRewards != null) {
            _setLatestRewardFromData(serverRewards);
          }
        });

        _sendDbStepsToService(serverUser.todaysStepCount);
      }
    } catch (e) {
      print("[Background Fetch] Error: $e (not critical, using cached data)");
      // Silently fail - we already have cached data showing
    }
  }

  void _sendDbStepsToService(int? steps) async {
    if (steps != null && mounted) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final localStepCount = prefs.getInt('local_step_count');
        final localStepCountDate = prefs.getString('local_step_count_date');
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        if (localStepCountDate != null && localStepCountDate != today) {
          try {
            final localDate = DateTime.parse(localStepCountDate);
            final todayDate = DateTime.parse(today);

            if (localDate.isBefore(todayDate)) {
              print(
                "🗓️ [HomeScreen] Local step count is from PREVIOUS day $localStepCountDate, clearing it. Today is $today.",
              );
              await prefs.remove('local_step_count');
              await prefs.remove('local_step_count_date');
            } else {
              print(
                "🗓️ [HomeScreen] Local step count date $localStepCountDate is valid.",
              );
              if (steps <= localStepCount!) {
                print(
                  "🔑 [HomeScreen] IGNORING DB steps ($steps) - Local step count ($localStepCount) from today is SOURCE OF TRUTH",
                );
                return;
              }
            }
          } catch (e) {
            print("[HomeScreen] Error parsing dates: $e. Keeping local count.");
            if (localStepCount != null && steps <= localStepCount) {
              return; // Keep local count on error
            }
          }
        } else if (localStepCountDate == null && localStepCount != null) {
          print(
            "[HomeScreen] Local step count has no date, assuming today.",
          );
          await prefs.setString('local_step_count_date', today);
          if (steps <= localStepCount) {
            print(
              "🔑 [HomeScreen] IGNORING DB steps ($steps) - Local step count ($localStepCount) is SOURCE OF TRUTH",
            );
            return;
          }
        } else if (localStepCount != null &&
            localStepCountDate == today &&
            steps <= localStepCount) {
          return;
        } else if (localStepCount != null && steps > localStepCount) {
        } else {
          print(
            "[HomeScreen] No local step count found. Sending DB steps ($steps) to StepProvider.",
          );
        }
      } catch (e) {
        print("[HomeScreen] Error checking local step count: $e");
      }

      print("[HomeScreen] Sending DB steps ($steps) to StepProvider.");
      context.read<StepProvider>().sendDbStepsToService(steps);
    } else {
      print(
        "[HomeScreen] Not sending DB steps to service (value is null or not mounted).",
      );
    }
  }

  Future<void> _loadData({
    bool forceRefresh = false,
    bool isInitialLoad = false,
  }) async {
    if (!mounted || _isLoadingData) return;
    _debounce?.cancel();
    _stepSubscription?.cancel();

    final prefs = await SharedPreferences.getInstance();
    final currentUser = FirebaseAuth.instance.currentUser;
    UserModel? loadedUser;
    Map<String, dynamic>? loadedRewards;
    if (isInitialLoad) {
      UserModel? cachedUser = await _loadUserFromCache(prefs);
      Map<String, dynamic>? cachedRewards = _loadRewardsFromCacheSync(prefs);

      if (cachedUser != null && mounted) {
        print("[Data Sync] Initial load: Displaying cached data immediately.");
        setState(() {
          _user = cachedUser;
          _isLoading = false; // Show UI immediately
          _isLoadingData = false;
          if (cachedRewards != null) {
            _setLatestRewardFromData(cachedRewards);
          }
        });
        _initStepCounter(cachedUser);
        _sendDbStepsToService(cachedUser.todaysStepCount);
        _fetchFreshDataInBackground(prefs, currentUser);
        return;
      } else if (mounted) {
        print(
          "[Data Sync] Initial load: No cache found, fetching from server.",
        );
        setState(() {
          _isLoading = true;
          _isLoadingData = true;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingData = true;
          if (forceRefresh) {
            _isLoading = true;
          }
        });
      }
    }
    const refreshThreshold = Duration(minutes: 15);
    final lastRefreshString = prefs.getString('lastProfileRefreshTimestamp');
    bool shouldFetchFromServer = false;
    if (currentUser == null) {
      print("[Data Sync] No user logged in, cannot fetch from server.");
      shouldFetchFromServer = false;
    } else if (forceRefresh) {
      shouldFetchFromServer = true;
      print("[Data Sync] Force refresh requested.");
    } else if (isInitialLoad && _user == null) {
      shouldFetchFromServer = true;
      print("[Data Sync] Initial load with no cache, fetching from server.");
    } else if (lastRefreshString == null) {
      shouldFetchFromServer = true;
      print("[Data Sync] No last refresh timestamp, fetching from server.");
    } else {
      final lastRefreshTime = DateTime.tryParse(lastRefreshString);
      if (lastRefreshTime != null &&
          DateTime.now().difference(lastRefreshTime) > refreshThreshold) {
        shouldFetchFromServer = true;
        print("[Data Sync] Refresh threshold exceeded, fetching from server.");
      } else {
        print("[Data Sync] No server fetch needed (cache is recent enough).");
      }
    }
    if (shouldFetchFromServer && currentUser != null) {
      print("[Data Sync] Attempting to fetch latest data from server...");
      try {
        final results = await Future.wait([
          _authService.refreshUserProfile(currentUser.uid),
          _authService.getUserRewards(currentUser.uid),
        ]);
        final serverUser = results[0] as UserModel?;
        final serverRewards = results[1] as Map<String, dynamic>?;
        if (serverUser != null) {
          loadedUser = serverUser;
          print(
            "[Data Sync] SUCCESS: Fetched user from server. Steps: ${loadedUser.todaysStepCount}",
          );
          _sendDbStepsToService(loadedUser.todaysStepCount);
          if (loadedUser.todaysStepCount == 0 &&
              prefs.getInt('dailyStepOffset') != null) {
            final localStepCount = prefs.getInt('local_step_count');
            final localStepCountDate = prefs.getString('local_step_count_date');
            final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

            // Only clear offset if NO valid local steps for today
            if (localStepCount == null ||
                localStepCount == 0 ||
                localStepCountDate != today) {
              final storedTimestamp = prefs.getInt('dailyOffsetTimestamp');
              if (storedTimestamp != null) {
                final offsetDate = DateTime.fromMillisecondsSinceEpoch(
                  storedTimestamp,
                );
                final now = DateTime.now();
                if (offsetDate.year == now.year &&
                    offsetDate.month == now.month &&
                    offsetDate.day == now.day) {
                  print(
                    "[Data Sync] Server reported 0 steps but offset is from today; keeping stored offset.",
                  );
                } else {
                  print(
                    "[Data Sync] Server reported 0 steps. Clearing local step offset from previous day.",
                  );
                  await prefs.remove('dailyStepOffset');
                  await prefs.remove('dailyOffsetTimestamp');
                  _offsetInitializationDone = false;
                }
              } else {
                print(
                  "[Data Sync] Server reported 0 steps and no offset timestamp found; clearing offset.",
                );
                await prefs.remove('dailyStepOffset');
                _offsetInitializationDone = false;
              }
            } else {
              // ✅ KEEP offset - we have valid local steps!
              print(
                "[Data Sync] ✅ DB returned 0 but local_step_count is $localStepCount from $localStepCountDate. KEEPING offset to preserve steps.",
              );
            }
          }
          if (serverRewards != null) {
            loadedRewards = serverRewards;
            await prefs.setString(
              'userRewardsCache',
              jsonEncode(serverRewards),
            ); // Update rewards cache
            print("[Data Sync] SUCCESS: Fetched rewards from server.");
          } else {
            print(
              "[Data Sync] WARNING: Fetched user but rewards fetch returned null.",
            );
            loadedRewards = _loadRewardsFromCacheSync(prefs);
          }
          await prefs.setString(
            'lastProfileRefreshTimestamp',
            DateTime.now().toIso8601String(),
          );
        } else {
          print(
            "[Data Sync] WARNING: Server user fetch returned null. Falling back to cache.",
          );
          loadedUser = await _loadUserFromCache(prefs);
          loadedRewards = _loadRewardsFromCacheSync(
            prefs,
          ); // Also load rewards from cache
        }
      } catch (e) {
        print(
          "[Data Sync] ERROR fetching from server: $e. Falling back to cache.",
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Network error. Showing cached data.'),
              backgroundColor: Colors.orange[800],
            ),
          );
        }
        loadedUser = await _loadUserFromCache(prefs);
        loadedRewards = _loadRewardsFromCacheSync(prefs);
        _sendDbStepsToService(loadedUser?.todaysStepCount);
      }
    } else if (!shouldFetchFromServer && _user == null) {
      print("[Data Sync] Not fetching from server, attempting cache load.");
      loadedUser = await _loadUserFromCache(prefs);
      loadedRewards = _loadRewardsFromCacheSync(prefs);
      _sendDbStepsToService(loadedUser?.todaysStepCount);
    } else {
      loadedUser = _user;
      loadedRewards = _loadRewardsFromCacheSync(prefs);
      print("[Data Sync] Using already loaded user data.");
      _sendDbStepsToService(loadedUser?.todaysStepCount);
    }
    if (mounted) {
      bool hadUserBefore = _user != null;
      setState(() {
        if (loadedUser != null) {
          _user = loadedUser;
          // StepProvider now manages step display
          if (loadedRewards != null) {
            _setLatestRewardFromData(loadedRewards);
          }
        } else {
          print(
            "[Data Sync] Final setState: Failed to load user from server and cache.",
          );

          if (isInitialLoad) _isLoading = true;

          if (!isInitialLoad && hadUserBefore) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to load user data. Check connection.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        _isLoadingData = false; // Data loading process finished

        if (loadedUser != null || !(isInitialLoad || forceRefresh)) {
          _isLoading = false;
        }
        print(
          "[Data Sync] Final isLoading=$_isLoading, isLoadingData=$_isLoadingData",
        );
      });
      if (loadedUser != null) {
        _initStepCounter(loadedUser);
      }
    }
  }

  void _initStepCounter(UserModel? userFromLoad) async {
    if (_offsetInitializationDone) {
      print(
        "[Step Counter] Offset initialization already completed this session. Skipping.",
      );
      _sendDbStepsToService(_user?.todaysStepCount);
      return;
    }
    _stepSubscription?.cancel(); // Cancel previous listener if any
    final prefs = await SharedPreferences.getInstance();
    await _healthService.initialize();

    int? storedOffset;
    int? offsetTimestampMillis;
    bool needsNewOffset = true; // Assume we need a new one by default

    try {
      storedOffset = prefs.getInt('dailyStepOffset');
      offsetTimestampMillis = prefs.getInt('dailyOffsetTimestamp');
      print(
        "[Step Counter] Initializing. Offset from cache: $storedOffset, TimestampMillis: $offsetTimestampMillis",
      );

      if (storedOffset != null && offsetTimestampMillis != null) {
        final offsetDate = DateTime.fromMillisecondsSinceEpoch(
          offsetTimestampMillis,
        );
        final nowDate = DateTime.now();
        if (offsetDate.year == nowDate.year &&
            offsetDate.month == nowDate.month &&
            offsetDate.day == nowDate.day) {
          needsNewOffset = false; // Offset is from today, use it!
          print(
            "[Step Counter] Offset timestamp is from today. Using existing offset: $storedOffset",
          );
        } else {
          print(
            "[Step Counter] Offset timestamp is from a previous day (${DateFormat('yyyy-MM-dd').format(offsetDate)}). Will calculate a new one.",
          );
        }
      } else {
        print(
          "[Step Counter] No valid offset or timestamp found in cache. Will calculate a new one.",
        );
      }
    } catch (e) {
      print(
        "[Step Counter] ERROR reading offset/timestamp during init: $e. Assuming new offset needed.",
      );
      needsNewOffset = true;
      storedOffset = null;
    }

    if (!needsNewOffset && storedOffset != null) {
      print(
        "[Step Counter] Offset timestamp is from today. Verifying against current pedometer reading.",
      );
      int currentReading = storedOffset ?? 0;
      StreamSubscription<String>? tempSub;
      final completer = Completer<int>();
      try {
        tempSub = _healthService.stepStream.listen(
          (stepsStr) {
            final v = int.tryParse(stepsStr);
            if (v != null) {
              if (!completer.isCompleted) completer.complete(v);
              tempSub?.cancel();
            }
          },
          onError: (_) {
            needsNewOffset = true;
            tempSub?.cancel();
          },
        );
        try {
          currentReading = await completer.future.timeout(
            const Duration(seconds: 5),
          );
        } on TimeoutException {
          print(
            "[Step Counter] Peek timeout; will recompute offset from next pedometer event.",
          );
          needsNewOffset = true;
          await tempSub?.cancel();
        }
      } catch (_) {
        currentReading = storedOffset ?? currentReading;
        await tempSub?.cancel();
      }

      const int resetThreshold = 100;
      if (currentReading < storedOffset - resetThreshold) {
        // Recompute offset using DB baseline due to reboot/reset
        final int dbSteps = userFromLoad?.todaysStepCount ?? 0;
        final int newOffset = currentReading - dbSteps;
        try {
          await prefs.setInt('dailyStepOffset', newOffset);
          await prefs.setInt(
            'dailyOffsetTimestamp',
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (e) {}
        FlutterForegroundTask.sendDataToTask({'offset': newOffset});
        _offsetInitializationDone = true;
        print(
          "[Step Counter] Marked offset initialization as DONE (recomputed after reset).",
        );
        return;
      } else {
        FlutterForegroundTask.sendDataToTask({'offset': storedOffset});
        _offsetInitializationDone = true;
        print(
          "[Step Counter] Marked offset initialization as DONE (using existing).",
        );
        return;
      }
    }
    print(
      "[Step Counter] Listening for pedometer reading to calculate NEW offset...",
    );
    _stepSubscription = _healthService.stepStream.listen(
      (stepsStr) async {
        if (_isLoadingData) {
          print(
            "[Step Counter] Ignored step event (calculating offset), data is loading.",
          );
          return;
        }
        final currentPedometerReading = int.tryParse(stepsStr);
        if (currentPedometerReading == null || currentPedometerReading < 0) {
          print(
            "[Step Counter] Invalid pedometer reading ($stepsStr) received while calculating offset.",
          );
          return;
        }
        final dbSteps = userFromLoad?.todaysStepCount ?? 0;
        int calculatedOffset = currentPedometerReading - dbSteps;
        final nowMillis = DateTime.now().millisecondsSinceEpoch;
        try {
          await prefs.setInt('dailyStepOffset', calculatedOffset);
          await prefs.setInt('dailyOffsetTimestamp', nowMillis);
          needsNewOffset = false;
          print(
            "[Step Counter] NEW Daily Step Offset PERSISTED: $calculatedOffset (Pedometer: $currentPedometerReading, Server Steps: $dbSteps)",
          );
          print("[Step Counter] Offset Timestamp PERSISTED: $nowMillis");

          FlutterForegroundTask.sendDataToTask({'offset': calculatedOffset});
          _stepSubscription?.cancel();
          _stepSubscription = null;
          print(
            "[Step Counter] New offset calculated and sent. HomeScreen stopping its pedometer listener.",
          );
          _offsetInitializationDone = true;
          print("[Step Counter] Marked offset initialization as DONE.");
        } catch (e) {
          print(
            "[Step Counter] ERROR saving newly calculated offset/timestamp: $e.",
          );
        }
      },
      onError: (error) {
        print(
          "[Step Counter] Error from step stream while calculating offset: $error",
        );
        _stepSubscription?.cancel();
        _stepSubscription = null;
      },
    );
  }

  Future<void> _saveLatestSteps(int stepsToSave) async {
    if (_isLoadingData) return;
    final UserModel? currentUserState = _user;
    if (currentUserState == null || currentUserState.userId.isEmpty) return;

    final int lastKnownStepsInState = currentUserState.todaysStepCount ?? 0;
    const int resetThreshold = 100;
    if (lastKnownStepsInState > resetThreshold &&
        stepsToSave < lastKnownStepsInState - resetThreshold) {
      print(
        "[Step Save] ⚠️ Potential Pedometer Reset Detected! Skipping sync.",
      );
      print(
        "   -> Last Known DB/State Steps: $lastKnownStepsInState, Steps Calculated Now: $stepsToSave",
      );
      return;
    }

    if (lastKnownStepsInState == stepsToSave) return;

    print(
      "[Step Save] Saving calculated step count: $stepsToSave for user ${currentUserState.userId}",
    );
    try {
      await _authService.syncStepsToBackend(
        currentUserState.userId,
        stepsToSave,
      );
      final updatedUserForCache = currentUserState.copyWith(
        todaysStepCount: stepsToSave,
      );
      await _authService.saveUserSession(updatedUserForCache);

      if (mounted) {
        setState(() {
          _user = updatedUserForCache;
          print(
            "[Step Save] setState: Updated _user.todaysStepCount to $stepsToSave",
          );
        });
        _sendDbStepsToService(stepsToSave);
      }
      print(
        "✅ [Step Save] Successfully saved steps to backend and updated local cache/state.",
      );
    } catch (e) {
      print("❌ [Step Save] Error saving step count: $e");
    }
  }

  void _showFriendBattleDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: const Text(
          'Battle a Friend',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Create a new battle or join an existing one.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleStartFriendBattle();
            },
            child: const Text(
              'Start Battle',
              style: TextStyle(color: Color(0xFFFFC107)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleJoinFriendBattle();
            },
            child: const Text(
              'Join Battle',
              style: TextStyle(color: Color(0xFFFFC107)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStartFriendBattle() async {
    if (_user == null) return;
    setState(() => _isHandlingFriendGame = true);
    try {
      final gameId = await _gameService.createFriendGame(_user!);
      context.read<ActiveBattleService>().startBattle(gameId, _user!);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                WaitingForFriendScreen(gameId: gameId, user: _user!),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackbar('Failed to create game: $e');
    } finally {
      if (mounted) setState(() => _isHandlingFriendGame = false);
    }
  }

  void _handleJoinFriendBattle() {
    final gameIdController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: const Text('Join Battle', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: gameIdController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Enter Game ID',
            labelStyle: TextStyle(color: Colors.white70),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFFFC107)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              final gameId = gameIdController.text.trim();
              if (gameId.isNotEmpty) {
                Navigator.of(ctx).pop();
                _joinGameById(gameId);
              } else {
                _showErrorSnackbar('Please enter a Game ID.');
              }
            },
            child: const Text(
              'Join',
              style: TextStyle(color: Color(0xFFFFC107)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinGameById(String gameId) async {
    if (_user == null) return;
    setState(() => _isHandlingFriendGame = true);
    try {
      final success = await _gameService.joinFriendGame(gameId, _user!);
      if (success && mounted) {
        context.read<ActiveBattleService>().startBattle(gameId, _user!);
        if (mounted) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const BattleScreen()));
        }
      } else if (!success) {
        _showErrorSnackbar(
          'Could not join game. It might be full, invalid, or already started.',
        );
      }
    } catch (e) {
      _showErrorSnackbar('Error joining game: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isHandlingFriendGame = false);
      }
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading || _user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator(color: Colors.yellow)),
      );
    }
    final safeUser = _user!;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: RefreshIndicator(
        onRefresh: () => _loadData(forceRefresh: true),
        color: Colors.yellow,
        backgroundColor: Colors.grey.shade900,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16.0,
                16.0,
                16.0,
                40.0 +
                    MediaQuery.of(
                      context,
                    ).padding.bottom, // Add bottom padding for all devices
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HomeHeader(
                      username: safeUser.username ?? 'User',
                      coins: safeUser.coins ?? 0,
                    ),
                    if (!_isPedometerPermissionGranted ||
                        !_isBatteryOptimizationEnabled)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFFC107).withOpacity(0.15),
                              const Color(0xFFFF9800).withOpacity(0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: const Color(0xFFFFC107).withOpacity(0.3),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFC107).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.security,
                                color: Color(0xFFFFC107),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Permissions Needed",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    !_isPedometerPermissionGranted
                                        ? "Grant permissions for full app experience"
                                        : "Battery optimization needed for background tracking",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _showPermissionSheet,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFC107),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                "Fix",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Consumer<StepProvider>(
                      builder: (context, stepProvider, child) {
                        return Showcase(
                          key: widget.stepCountKey,
                          title: 'Daily Steps',
                          description:
                              'Your steps are your power!\nWalk more to collect rewards.',
                          tooltipBackgroundColor: const Color(0xFF1E1E1E),
                          textColor: Colors.white,
                          tooltipBorderRadius: BorderRadius.circular(12),
                          targetShapeBorder: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: StepCounterCard(
                            steps: stepProvider.currentSteps,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    const SectionTitle(
                      title: "---------- Today's Scorecard ----------",
                    ),
                    const SizedBox(height: 16),
                    ScorecardSection(stats: safeUser.stats ?? {}),
                    const SizedBox(height: 16),
                    BattleSection(
                      user: safeUser,
                      opponentProfile: _opponentProfile,
                      isCreatingGame: _isCreatingGame,
                      isCreatingBotGame: _isCreatingBotGame,
                      onShowFriendBattleDialog: _showFriendBattleDialog,
                      onFetchOpponentProfile: _fetchOpponentProfile,
                      onlineBattleKey: widget.onlineBattleKey,
                      friendBattleKey: widget.friendBattleKey,
                    ),
                    const SizedBox(height: 16),
                    const GameRulesWidget(),
                    const SizedBox(height: 24),
                    const SectionTitle(
                      title: "---------- Mystery Box ----------",
                    ),
                    const SizedBox(height: 16),
                    MysteryBoxSection(
                      onOpenBox: _openMysteryBox,
                      isOpeningBronze: _isOpeningBronzeBox,
                      isOpeningSilver: _isOpeningSilverBox,
                      isOpeningGold: _isOpeningGoldBox,
                      bronzeTimeLeft: _bronzeTimeLeft,
                      silverTimeLeft: _silverTimeLeft,
                      goldTimeLeft: _goldTimeLeft,
                    ),
                    const SizedBox(height: 16),
                    const StepWarsFooter(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      // floatingActionButton: Consumer<StepProvider>(
      //   builder: (context, stepProvider, child) {
      //     return Showcase(
      //       key: widget.googleFitKey,
      //       description: 'Check your detailed\nGoogle Fit statistics',
      //       tooltipBackgroundColor: const Color(0xFF1E1E1E),
      //       textColor: Colors.white,
      //       tooltipBorderRadius: BorderRadius.circular(12),
      //       targetShapeBorder: const CircleBorder(),
      //       child: FloatingActionButton.extended(
      //         onPressed: () {
      //           Navigator.push(
      //             context,
      //             MaterialPageRoute(
      //               builder: (context) => const GoogleFitStatsScreen(),
      //             ),
      //           );
      //         },
      //         icon: const Icon(Icons.bar_chart),
      //         label: const Text('Google Fit'),
      //         backgroundColor: Colors.blue,
      //         foregroundColor: Colors.white,
      //       ),
      //     );
      //   },
      // ),
    );
  }

  // No additional method needed here
}
