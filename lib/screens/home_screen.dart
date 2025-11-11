// ignore_for_file: unused_import, unused_field
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stepwars_app/services/active_battle_service.dart';
import 'package:stepwars_app/services/bot_service.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/game_service.dart';
import '../services/step_counting.dart';
import '../widget/footer.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
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
  int _stepsToShow = 0;
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
  bool _offsetInitializationDone = false;
  DateTime? _lastPausedTime;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _offsetInitializationDone = false;
    _debounce?.cancel();
    _stepSubscription?.cancel();
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _requestPermissions();
      _initService();
      await _startService();
      _checkForOngoingBattle();
    });
    _loadData(isInitialLoad: true);
    _handleNotifications();
    WidgetsBinding.instance.addObserver(this);
    _startBoxTimers();
  }

 Future<void> _checkForOngoingBattle() async {
    if (!mounted) return;
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final battleService = context.read<ActiveBattleService>();
      if (battleService.isBattleActive && battleService.isWaitingForFriend && _user != null) {
        final gameId = battleService.currentGame?.gameId;
        if (gameId != null) {
          // Navigate to the WaitingForFriendScreen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => WaitingForFriendScreen(
                    gameId: gameId, 
                    user: _user!,
                  ),
                ),
                (route) => route.isFirst,
              );
            }
          });
        }
      }
      print("Battle service state - isBattleActive: ${battleService.isBattleActive}, isWaitingForFriend: ${battleService.isWaitingForFriend}");
    } catch (e) {
      print("Error checking for ongoing battle: $e");
    }
  }

  void _onReceiveTaskData(Object data) {
    if (data is Map<String, dynamic>) {
      if (data.containsKey('steps')) {
        final stepsFromService = data['steps'] as int;
        final int dbSteps = _user?.todaysStepCount ?? 0;

        if (mounted && _stepsToShow != stepsFromService) {
          // Only setState if value changed
          setState(() {
            _stepsToShow = stepsFromService;
          });
        }

        // If UI is still stuck at DB baseline after reboot, force offset recompute once
        if (_offsetInitializationDone && stepsFromService == dbSteps) {
          StreamSubscription<String>? tempSub;
          final completer = Completer<int>();
          try {
            tempSub = _healthService.stepStream.listen((stepsStr) {
              final v = int.tryParse(stepsStr);
              if (v != null) {
                if (!completer.isCompleted) completer.complete(v);
                tempSub?.cancel();
              }
            }, onError: (_) {
              if (!completer.isCompleted) completer.complete(dbSteps);
              tempSub?.cancel();
            });

            completer.future.timeout(const Duration(seconds: 5)).then((current) async {
              const int threshold = 10;
              if (current > dbSteps + threshold) {
                final int newOffset = current - dbSteps;
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('dailyStepOffset', newOffset);
                  await prefs.setInt('dailyOffsetTimestamp', DateTime.now().millisecondsSinceEpoch);
                  FlutterForegroundTask.sendDataToTask({'offset': newOffset});
                  print('[HomeScreen] Forced offset recompute after stuck detection. newOffset=' + newOffset.toString());
                } catch (e) {
                  print('[HomeScreen] ERROR persisting forced offset: ' + e.toString());
                }
              }
            }).catchError((_) {});
          } catch (_) {
            tempSub?.cancel();
          }
        }

        _debounce?.cancel();
        _debounce = Timer(const Duration(minutes: 30),
            () => _saveLatestSteps(stepsFromService));
      }
    }
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    _debounce?.cancel();
    _healthService.dispose();
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
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
      _debounce?.cancel();
      _stepSubscription?.cancel(); // Add this
      await _saveLatestSteps(_stepsToShow);
    }
    if (state == AppLifecycleState.resumed) {
      print("App resumed. Cancelling pending saves & triggering data load.");
      _debounce?.cancel();
      _stepSubscription?.cancel();
      final bool wasPausedLong = _lastPausedTime != null && 
                                 DateTime.now().difference(_lastPausedTime!).inMinutes >= 1;
    if (wasPausedLong || _user == null) {
        print("App was paused for > 1 min OR user is null. Triggering data load.");
        if (mounted) {
          _loadData();
        }
      } else {
        print("App resumed from brief pause. Skipping full data load.");
      }
      _lastPausedTime = null; // Clear the paused time
    }
  }

  Future<void> _requestPermissions() async {
    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
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
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    } else {
      return FlutterForegroundTask.startService(
        serviceId: 101,
        notificationTitle: 'Step Counter Running',
        notificationText: 'Steps: 0',
        // notificationIcon:
        //     const NotificationIcon(metaDataName: '@drawable/ic_notification'),
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
            backgroundColor: Colors.red),
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
      final reward =
          await _mysteryBoxService.openMysteryBox(_user!.userId, boxType);
      final newCoinBalance = reward['newCoinBalance'] as int?;
      if (newCoinBalance != null && mounted) {
        setState(() {
          final updatedLastOpened =
              Map<String, String>.from(_user!.mysteryBoxLastOpened ?? {});
          updatedLastOpened[boxType] = DateTime.now().toIso8601String();
          _user = _user!.copyWith(
              coins: newCoinBalance, mysteryBoxLastOpened: updatedLastOpened);
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
              backgroundColor: Colors.red),
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
        title: const Text('Confirm Purchase',
            style: TextStyle(color: Colors.white)),
        content: Text('Open the ${boxType.capitalize()} box for $price coins?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm',
                style: TextStyle(color: Color(0xFFFFC107))),
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
              fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black),
        );
        break;
      case 'collectible':
        final item = reward['item'];
        titleText = "New Collectible!";
        subtitleText = item?['name'] ?? 'A new item';
        final imagePath = (item is Map && item.containsKey('imagePath'))
            ? item['imagePath']
            : null;
        rewardContent = imagePath != null
            ? Image.asset(imagePath,
                height: 80,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.shield, size: 80, color: Colors.black))
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
            user.uid, token);
        if (success) {
          await prefs.setBool('hasRegisteredFcmToken', true);
        }
      }
    }
  }

  Future<void> _fetchOpponentProfile(ActiveBattleService battleService) async {
    if (_isFetchingOpponent ||
        _opponentProfile != null ||
        battleService.currentGame == null) {
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
        _opponentProfile = opponent;
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

  void _sendDbStepsToService(int? steps) {
    if (steps != null) {
      print("[HomeScreen] Sending DB steps ($steps) to service.");
      FlutterForegroundTask.sendDataToTask({'dbSteps': steps});
    } else {
      print("[HomeScreen] Not sending DB steps to service (value is null).");
    }
  }

  Future<void> _loadData(
      {bool forceRefresh = false, bool isInitialLoad = false}) async {
    if (!mounted || _isLoadingData) return;
    _debounce?.cancel();
    _stepSubscription?.cancel();
    if (mounted) {
      setState(() {
        _isLoadingData = true;
        if (isInitialLoad || forceRefresh) {
          _isLoading = true;
        }
      });
    }
    final prefs = await SharedPreferences.getInstance();
    final currentUser = FirebaseAuth.instance.currentUser;
    UserModel? loadedUser;
    Map<String, dynamic>? loadedRewards;
    if (isInitialLoad && !_isLoading) {
      UserModel? cachedUser = await _loadUserFromCache(prefs);
      Map<String, dynamic>? cachedRewards = _loadRewardsFromCacheSync(prefs);
      if (cachedUser != null && mounted) {
        print("[Data Sync] Initial load: Displaying cached data first.");
        setState(() {
          _user = cachedUser;
          _stepsToShow = cachedUser.todaysStepCount ?? 0;
          if (cachedRewards != null) {
            _setLatestRewardFromData(cachedRewards);
          }
        });
        _initStepCounter(cachedUser);
        _sendDbStepsToService(cachedUser.todaysStepCount); // Send cached steps
      } else if (mounted) {
        print(
            "[Data Sync] Initial load: No cache found, setting isLoading = true.");
        setState(() {
          _isLoading = true;
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
          _authService.getUserRewards(currentUser.uid)
        ]);
        final serverUser = results[0] as UserModel?;
        final serverRewards = results[1] as Map<String, dynamic>?;
        if (serverUser != null) {
          loadedUser = serverUser;
          print(
              "[Data Sync] SUCCESS: Fetched user from server. Steps: ${loadedUser.todaysStepCount}");
          _sendDbStepsToService(loadedUser.todaysStepCount);
          if (loadedUser.todaysStepCount == 0 &&
              prefs.getInt('dailyStepOffset') != null) {
            final storedTimestamp = prefs.getInt('dailyOffsetTimestamp');
            if (storedTimestamp != null) {
              final offsetDate =
                  DateTime.fromMillisecondsSinceEpoch(storedTimestamp);
              final now = DateTime.now();
              if (offsetDate.year == now.year &&
                  offsetDate.month == now.month &&
                  offsetDate.day == now.day) {
                print(
                    "[Data Sync] Server reported 0 steps but offset is from today; keeping stored offset.");
                // keep today's offset — no action required
              } else {
                print(
                    "[Data Sync] Server reported 0 steps. Clearing local step offset from previous day.");
                await prefs.remove('dailyStepOffset');
                await prefs.remove('dailyOffsetTimestamp');
                _offsetInitializationDone = false;
              }
            } else {
              print(
                  "[Data Sync] Server reported 0 steps and no offset timestamp found; keeping stored offset to avoid recalculation.");
              await prefs.remove('dailyStepOffset');
              _offsetInitializationDone = false;
            }
          }
          if (serverRewards != null) {
            loadedRewards = serverRewards;
            await prefs.setString('userRewardsCache',
                jsonEncode(serverRewards)); // Update rewards cache
            print("[Data Sync] SUCCESS: Fetched rewards from server.");
          } else {
            print(
                "[Data Sync] WARNING: Fetched user but rewards fetch returned null.");
            loadedRewards = _loadRewardsFromCacheSync(prefs);
          }
          await prefs.setString(
              'lastProfileRefreshTimestamp', DateTime.now().toIso8601String());
        } else {
          print(
              "[Data Sync] WARNING: Server user fetch returned null. Falling back to cache.");
          loadedUser = await _loadUserFromCache(prefs);
          loadedRewards =
              _loadRewardsFromCacheSync(prefs); // Also load rewards from cache
        }
      } catch (e) {
        print(
            "[Data Sync] ERROR fetching from server: $e. Falling back to cache.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Network error. Showing cached data.'),
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
          int? dbSteps = loadedUser.todaysStepCount;
          if (dbSteps != null &&
              (dbSteps > _stepsToShow || _stepsToShow == 0)) {
            print(
                "[Data Sync] setState: DB steps ($dbSteps) are higher or current is 0. Updating _stepsToShow.");
            _stepsToShow = dbSteps;
          } else {
            print(
                "[Data Sync] setState: DB steps (${dbSteps ?? 'null'}) NOT higher than current display ($_stepsToShow). _stepsToShow remains unchanged by DB load.");
          }
          if (loadedRewards != null) {
            _setLatestRewardFromData(loadedRewards);
          }
        } else {
          print(
              "[Data Sync] Final setState: Failed to load user from server and cache.");

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
            "[Data Sync] Final isLoading=$_isLoading, isLoadingData=$_isLoadingData");
      });
      if (loadedUser != null) {
        _initStepCounter(loadedUser);
      }
    }
  }

  void _initStepCounter(UserModel? userFromLoad) async {
    if (_offsetInitializationDone) {
      print(
          "[Step Counter] Offset initialization already completed this session. Skipping.");
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
          "[Step Counter] Initializing. Offset from cache: $storedOffset, TimestampMillis: $offsetTimestampMillis");

      if (storedOffset != null && offsetTimestampMillis != null) {
        // Check if the stored offset is from today
        final offsetDate =
            DateTime.fromMillisecondsSinceEpoch(offsetTimestampMillis);
        final nowDate = DateTime.now();
        // Compare Year, Month, Day in local time
        if (offsetDate.year == nowDate.year &&
            offsetDate.month == nowDate.month &&
            offsetDate.day == nowDate.day) {
          needsNewOffset = false; // Offset is from today, use it!
          print(
              "[Step Counter] Offset timestamp is from today. Using existing offset: $storedOffset");
        } else {
          print(
              "[Step Counter] Offset timestamp is from a previous day (${DateFormat('yyyy-MM-dd').format(offsetDate)}). Will calculate a new one.");
        }
      } else {
        print(
            "[Step Counter] No valid offset or timestamp found in cache. Will calculate a new one.");
      }
    } catch (e) {
      print(
          "[Step Counter] ERROR reading offset/timestamp during init: $e. Assuming new offset needed.");
      needsNewOffset = true;
      storedOffset = null;
    }

    if (!needsNewOffset && storedOffset != null) {
      print(
          "[Step Counter] Offset timestamp is from today. Verifying against current pedometer reading.");
      // Peek current pedometer reading to detect reboot/reset
      int currentReading = storedOffset ?? 0;
      StreamSubscription<String>? tempSub;
      final completer = Completer<int>();
      try {
        tempSub = _healthService.stepStream.listen((stepsStr) {
          final v = int.tryParse(stepsStr);
          if (v != null) {
            if (!completer.isCompleted) completer.complete(v);
            tempSub?.cancel();
          }
        }, onError: (_) {
          needsNewOffset = true;
          tempSub?.cancel();
        });
        try {
          currentReading = await completer.future.timeout(const Duration(seconds: 5));
        } on TimeoutException {
          print("[Step Counter] Peek timeout; will recompute offset from next pedometer event.");
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
          await prefs.setInt('dailyOffsetTimestamp', DateTime.now().millisecondsSinceEpoch);
          print("[Step Counter] Detected reset. NEW offset set to " + newOffset.toString() + " (current=" + currentReading.toString() + ", db=" + dbSteps.toString() + ").");
        } catch (e) {
          print("[Step Counter] ERROR persisting recomputed offset: " + e.toString());
        }
        FlutterForegroundTask.sendDataToTask({'offset': newOffset});
        _offsetInitializationDone = true;
        print(
            "[Step Counter] Marked offset initialization as DONE (recomputed after reset).");
        return;
      } else {
        print("[Step Counter] Using existing offset (" + storedOffset.toString() + "). No reset detected.");
        FlutterForegroundTask.sendDataToTask({'offset': storedOffset});
        _offsetInitializationDone = true;
        print(
            "[Step Counter] Marked offset initialization as DONE (using existing).");
        return;
      }
    }
    print(
        "[Step Counter] Listening for pedometer reading to calculate NEW offset...");
    _stepSubscription = _healthService.stepStream.listen((stepsStr) async {
      if (_isLoadingData) {
        print(
            "[Step Counter] Ignored step event (calculating offset), data is loading.");
        return;
      }
      final currentPedometerReading = int.tryParse(stepsStr);
      if (currentPedometerReading == null || currentPedometerReading < 0) {
        print(
            "[Step Counter] Invalid pedometer reading ($stepsStr) received while calculating offset.");
        return;
      }
      // DB steps should be 0 for a new day, fetched by _loadData
      final dbSteps = userFromLoad?.todaysStepCount ?? 0;
      int calculatedOffset = currentPedometerReading - dbSteps;
      final nowMillis = DateTime.now().millisecondsSinceEpoch;
      try {
        await prefs.setInt('dailyStepOffset', calculatedOffset);
        await prefs.setInt('dailyOffsetTimestamp', nowMillis);
        needsNewOffset = false;
        print(
            "[Step Counter] NEW Daily Step Offset PERSISTED: $calculatedOffset (Pedometer: $currentPedometerReading, Server Steps: $dbSteps)");
        print("[Step Counter] Offset Timestamp PERSISTED: $nowMillis");

        FlutterForegroundTask.sendDataToTask({'offset': calculatedOffset});
        _stepSubscription?.cancel();
        _stepSubscription = null;
        print(
            "[Step Counter] New offset calculated and sent. HomeScreen stopping its pedometer listener.");
        _offsetInitializationDone = true;
        print("[Step Counter] Marked offset initialization as DONE.");
      } catch (e) {
        print(
            "[Step Counter] ERROR saving newly calculated offset/timestamp: $e.");
      }
    }, onError: (error) {
      print(
          "[Step Counter] Error from step stream while calculating offset: $error");
      _stepSubscription?.cancel();
      _stepSubscription = null;
    });
  }

  Future<void> _saveLatestSteps(int stepsToSave) async {
      if (_isLoadingData) return;
      final UserModel? currentUserState = _user;
      if (currentUserState == null || currentUserState.userId.isEmpty) return;

      final int lastKnownStepsInState = currentUserState.todaysStepCount ?? 0;
      const int resetThreshold = 100;
      if (lastKnownStepsInState > resetThreshold && stepsToSave < lastKnownStepsInState - resetThreshold) {
          print("[Step Save] ⚠️ Potential Pedometer Reset Detected! Skipping sync.");
          print("   -> Last Known DB/State Steps: $lastKnownStepsInState, Steps Calculated Now: $stepsToSave");
          if (mounted && _stepsToShow != stepsToSave) {
             setState(() { _stepsToShow = stepsToSave; });
          }
          return;
      }

      if (lastKnownStepsInState == stepsToSave) return;

      print("[Step Save] Saving calculated step count: $stepsToSave for user ${currentUserState.userId}");
      try {
        await _authService.syncStepsToBackend(currentUserState.userId, stepsToSave);
        final updatedUserForCache = currentUserState.copyWith(todaysStepCount: stepsToSave);
        await _authService.saveUserSession(updatedUserForCache);

        if (mounted) {
          setState(() {
            _user = updatedUserForCache;
            print("[Step Save] setState: Updated _user.todaysStepCount to $stepsToSave");
          });
          _sendDbStepsToService(stepsToSave);
        }
        print("✅ [Step Save] Successfully saved steps to backend and updated local cache/state.");
      } catch (e) {
        print("❌ [Step Save] Error saving step count: $e");
      }
  }

  void _showFriendBattleDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: const Text('Battle a Friend',
            style: TextStyle(color: Colors.white)),
        content: const Text('Create a new battle or join an existing one.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleStartFriendBattle();
            },
            child: const Text('Start Battle',
                style: TextStyle(color: Color(0xFFFFC107))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleJoinFriendBattle();
            },
            child: const Text('Join Battle',
                style: TextStyle(color: Color(0xFFFFC107))),
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
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
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
            child:
                const Text('Join', style: TextStyle(color: Color(0xFFFFC107))),
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
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const BattleScreen()));
        }
      } else if (!success) {
        _showErrorSnackbar(
            'Could not join game. It might be full, invalid, or already started.');
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _user == null) {
      return const Scaffold(
          backgroundColor: Color(0xFF121212),
          body: Center(child: CircularProgressIndicator(color: Colors.yellow)));
    }
    final safeUser = _user!;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: RefreshIndicator(
        onRefresh: () => _loadData(forceRefresh: true),
        color: Colors.yellow,
        backgroundColor: Colors.grey.shade900,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeHeader(
                username: safeUser.username ?? 'User',
                coins: safeUser.coins ?? 0,
              ),
              const SizedBox(height: 16),
              StepCounterCard(steps: _stepsToShow),
              const SizedBox(height: 24),
              const SectionTitle(
                  title: "---------- Today's Scorecard ----------"),
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
              ),
              const SizedBox(height: 16),
              const GameRulesWidget(),
              const SizedBox(height: 24),
              const SectionTitle(title: "---------- Mystery Box ----------"),
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
      ),
    );
  }

  // No additional method needed here
}
