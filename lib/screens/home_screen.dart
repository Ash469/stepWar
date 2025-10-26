// ignore_for_file: unused_import, unused_field

import 'dart:async';
import 'dart:convert';
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

// --- REFACTORED WIDGETS ---
import '../widget/home/home_header.dart';
import '../widget/home/step_counter_card.dart';
import '../widget/home/scorecard_section.dart';
import '../widget/home/battle_section.dart';
import '../widget/home/rewards_section.dart';
import '../widget/home/section_title.dart';

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

  bool _isOffsetCalculated = false;
  bool _isLoadingData = false;

  @override
  void initState() {
    super.initState();
    _debounce?.cancel();
    _loadData(isInitialLoad: true);
    _handleNotifications();
    WidgetsBinding.instance.addObserver(this);
    _startBoxTimers();
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
      
      // --- MODIFICATION: Call the new calculation logic ---
      if (mounted) {
        setState(() {
          _bronzeTimeLeft = _calculateTimeLeft('bronze');
          _silverTimeLeft = _calculateTimeLeft('silver');
          _goldTimeLeft = _calculateTimeLeft('gold');
        });
      }
      // --- END MODIFICATION ---
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
        // If current time is before the 24-hour mark, calculate remaining duration
        return nextAvailableTime.difference(now);
      }
    } catch (e) {
      print("Error parsing mystery box date for $boxType: $e");
    }
    // If parsing failed or 24 hours have passed, return zero
    return Duration.zero;
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      print("App is pausing. Forcing final step save.");
      _debounce?.cancel(); 
      await _saveLatestSteps(_stepsToShow); 
    }
    if (state == AppLifecycleState.resumed) {
      print("App resumed. Cancelling pending saves & triggering data load.");
      _debounce?.cancel(); 
      _loadData(); 
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
                     final updatedLastOpened = Map<String, String>.from(_user!.mysteryBoxLastOpened ?? {});
           updatedLastOpened[boxType] = DateTime.now().toIso8601String(); 
          _user = _user!.copyWith(coins: newCoinBalance, mysteryBoxLastOpened: updatedLastOpened);

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
           style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black),
         );
         break;
       case 'collectible':
         final item = reward['item'];
         titleText = "New Collectible!";
         subtitleText = item?['name'] ?? 'A new item';
         final imagePath = (item is Map && item.containsKey('imagePath')) ? item['imagePath'] : null;
         rewardContent = imagePath != null
             ? Image.asset(imagePath, height: 80, errorBuilder: (_, __, ___) => const Icon(Icons.shield, size: 80, color: Colors.black))
             : const Icon(Icons.shield, size: 80, color: Colors.black);
         break;
       default:
         titleText = "Special Reward!";
         rewardContent = const Icon(Icons.star, size: 80, color: Colors.black);
     }

     if(mounted) {
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
    if(mounted) setState(() => _isFetchingOpponent = true);
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
        return user;
      } catch (e) {
        print("[Data Sync] Error parsing cache: $e");
        return null;
      }
    }
    return null;
  }

  Future<void> _loadData(
      {bool forceRefresh = false, bool isInitialLoad = false}) async {
    if (!mounted || _isLoadingData) return;

    _debounce?.cancel();
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

    if (forceRefresh) {
      print("[Data Sync] Manual refresh triggered. Saving local steps first (if possible).");
      try {
        await _saveLatestSteps(_stepsToShow);
      } catch (e) {
        print("[Data Sync] Error during pre-refresh save (ignoring): $e");
      }
    }

    const refreshThreshold = Duration(minutes: 5);
    final lastRefreshString = prefs.getString('lastProfileRefreshTimestamp');
    final hasCachedProfile = prefs.getString('userProfile') != null;

    bool shouldFetchFromServer = false;
    if (isInitialLoad && !hasCachedProfile) {
      shouldFetchFromServer = true;
      print("[Data Sync] Initial load with no cache - fetching from server");
    } else if (forceRefresh) {
      shouldFetchFromServer = true;
    } else if (lastRefreshString != null) {
      final lastRefreshTime = DateTime.tryParse(lastRefreshString);
      if (lastRefreshTime != null &&
          DateTime.now().difference(lastRefreshTime) > refreshThreshold) {
        shouldFetchFromServer = true;
      }
    } else {
      shouldFetchFromServer = true; 
    }
    
    if (shouldFetchFromServer && currentUser != null) {
      print("[Data Sync] Fetching latest data from server...");
     
      try {
        final results = await Future.wait([
          _authService.refreshUserProfile(currentUser.uid),
          _authService.getUserRewards(currentUser.uid)
        ]);

        final serverUser = results[0] as UserModel?;
        if (serverUser != null) {
          loadedUser = serverUser;
          print("[Data Sync] Fetched user from server. Steps: ${loadedUser.todaysStepCount}");

          if (loadedUser.todaysStepCount == 0 && prefs.getInt('dailyStepOffset') != null) {
            print("[Data Sync] Server reported 0 steps. Clearing local step offset.");
            await prefs.remove('dailyStepOffset');
            _isOffsetCalculated = false; // Reset flag
          }

          if (mounted) {
            setState(() {
              _user = loadedUser;
              _stepsToShow = loadedUser?.todaysStepCount ?? 0;
            });
          }
          final rawRewards = results[1] as Map<String, dynamic>?;
          if (rawRewards != null && mounted) {
            await prefs.setString('userRewardsCache', jsonEncode(rawRewards));
            _setLatestRewardFromData(rawRewards);
          }

          if (mounted) {
            await prefs.setString(
                'lastProfileRefreshTimestamp', DateTime.now().toIso8601String());
            print("[Data Sync] Saved new refresh timestamp.");
          }
        } else {
          print("[Data Sync] Fetch returned null user. Falling back to cache.");
          loadedUser = await _loadUserFromCache(prefs); // Use cache as fallback
        }

      } catch (e) {
        print("[Data Sync] Error during data fetch, falling back to cache: $e");
        loadedUser = await _loadUserFromCache(prefs);

      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isLoadingData = false;
          });
          _initStepCounter(loadedUser);
        }
      }
    } else if (hasCachedProfile) {
      print("[Data Sync] Loading data from cache (no fetch needed).");
      loadedUser = await _loadUserFromCache(prefs);
       if (mounted) {
        setState(() {
          _user = loadedUser;
          _stepsToShow = loadedUser?.todaysStepCount ?? 0;
          _isLoading = false;
          _isLoadingData = false;
        });
        _initStepCounter(loadedUser);
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingData = false;
        });
        _initStepCounter(null);
      }
    }
  }


  void _initStepCounter(UserModel? userFromLoad) async { 
    if (_isLoadingData) {
      print("[Step Counter] Delaying initialization, data is loading.");
      return;
    }

    _stepSubscription?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await _healthService.initialize();

    _isOffsetCalculated = prefs.getInt('dailyStepOffset') != null;
    print("[Step Counter] Initializing. Offset already calculated: $_isOffsetCalculated.");

    _stepSubscription = _healthService.stepStream.listen(
      (stepsStr) {
        if (_isLoadingData) { 
           print("[Step Counter] Ignored step event, data is loading.");
           return;
        }

        final currentPedometerReading = int.tryParse(stepsStr);
        if (currentPedometerReading == null) return;

        int? dailyStepOffset = prefs.getInt('dailyStepOffset');

        if (!_isOffsetCalculated && currentPedometerReading >= 0) { // Changed > 0 to >= 0
          // If offset is not calculated, it means server returned 0 steps
          // or this is the very first reading.
          final dbSteps = userFromLoad?.todaysStepCount ?? 0; 
          dailyStepOffset = currentPedometerReading - dbSteps;

          prefs.setInt('dailyStepOffset', dailyStepOffset);
          _isOffsetCalculated = true;

          print(
              "[Step Counter] New Daily Step Offset PERSISTED: $dailyStepOffset (Pedometer: $currentPedometerReading, Server Steps at Load: $dbSteps)");
        }
        
        if (dailyStepOffset == null) {
           // If offset is still null here (e.g., pedometer read 0 initially),
           // show the steps reported by the server/cache until offset is calculated.
           if(mounted) {
             setState(() {
               _stepsToShow = _user?.todaysStepCount ?? 0;
             });
           }
           print("[Step Counter] Offset not yet calculated. Showing DB steps: ${_user?.todaysStepCount ?? 0}");
           return;
        }

        final calculatedDailySteps = currentPedometerReading - dailyStepOffset;
        // Ensure steps don't go negative if pedometer resets mid-day
        final stepsToSave = calculatedDailySteps > 0 ? calculatedDailySteps : 0; 

        if (mounted) {
          setState(() {
            _stepsToShow = stepsToSave; // Update UI optimistically
          });
        }

        _debounce?.cancel();
        _debounce = Timer(
            const Duration(seconds: 15), () => _saveLatestSteps(stepsToSave));
      },
      onError: (error) {
        print("[Step Counter] Error from step stream: $error");
        if(mounted && !_isLoadingData) {
          setState(() {
            // Fallback to server/cache steps on error
            _stepsToShow = _user?.todaysStepCount ?? 0; 
          });
        }
      }
    );
  }

  Future<void> _saveLatestSteps(int stepsToSave) async {
    if (_isLoadingData) {
      print("[Step Save] Skipping save, data load in progress.");
      return;
    }
    final currentUserState = _user; 
    if (currentUserState == null || currentUserState.userId.isEmpty) {
      print("[Step Save] Skipping save: User data not available in state.");
      return;
    }

    
    if (currentUserState.todaysStepCount == stepsToSave) {
      return;
    }

    print(
        "[Step Save] Saving calculated step count: $stepsToSave for user ${currentUserState.userId}");
    try {
      // 1. Send to backend
      await _authService.syncStepsToBackend(currentUserState.userId, stepsToSave);

      // 2. Update local state and cache AFTER successful backend sync
      final updatedUserForCache = currentUserState.copyWith(todaysStepCount: stepsToSave);
      await _authService.saveUserSession(updatedUserForCache);
      if (mounted) {
         setState(() {
             _user = updatedUserForCache; // Update the main state variable
         });
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
        _showErrorSnackbar('Could not join game. It might be full, invalid, or already started.');
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
           SnackBar(
               content: Text(message),
               backgroundColor: Colors.redAccent,
           )
       );
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
              const SectionTitle(title: "---------- Today's Scorecard ----------"),
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
              // const SizedBox(height: 24),
              // const SectionTitle(title: "---------- Rewards ----------"),
              // const SizedBox(height: 16),
              // RewardsSection(latestReward: _latestReward),
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

}
