import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

/// Centralized persistence service for managing all app data using SharedPreferences
/// This service handles auth state, step counts, game data, and user preferences
class PersistenceService {
  static final PersistenceService _instance = PersistenceService._internal();
  factory PersistenceService() => _instance;
  PersistenceService._internal();

  SharedPreferences? _prefs;
  
  /// Initialize the persistence service
  Future<bool> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      if (kDebugMode) print('✅ PersistenceService initialized');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ PersistenceService initialization failed: $e');
      return false;
    }
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('PersistenceService not initialized. Call initialize() first.');
    }
    return _prefs!;
  }

  // MARK: - Authentication Data
  
  /// Save authentication state
  Future<void> saveAuthState({
    required bool isAuthenticated,
    String? userId,
    String? firebaseUserId,
    GameUser? user,
  }) async {
    try {
      await prefs.setBool('auth_is_authenticated', isAuthenticated);
      
      if (userId != null) {
        await prefs.setString('auth_user_id', userId);
      } else {
        await prefs.remove('auth_user_id');
      }
      
      if (firebaseUserId != null) {
        await prefs.setString('auth_firebase_user_id', firebaseUserId);
      } else {
        await prefs.remove('auth_firebase_user_id');
      }
      
      if (user != null) {
        await prefs.setString('auth_user_data', jsonEncode(user.toMap()));
      } else {
        await prefs.remove('auth_user_data');
      }
      
      if (kDebugMode) print('💾 Authentication state saved');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to save auth state: $e');
    }
  }

  /// Load authentication state
  Map<String, dynamic> loadAuthState() {
    try {
      final isAuthenticated = prefs.getBool('auth_is_authenticated') ?? false;
      final userId = prefs.getString('auth_user_id');
      final firebaseUserId = prefs.getString('auth_firebase_user_id');
      final userDataJson = prefs.getString('auth_user_data');
      
      GameUser? user;
      if (userDataJson != null) {
        final userData = jsonDecode(userDataJson) as Map<String, dynamic>;
        user = GameUser.fromMap(userData);
      }
      
      if (kDebugMode) print('📖 Authentication state loaded: $isAuthenticated');
      
      return {
        'isAuthenticated': isAuthenticated,
        'userId': userId,
        'firebaseUserId': firebaseUserId,
        'user': user,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Failed to load auth state: $e');
      return {
        'isAuthenticated': false,
        'userId': null,
        'firebaseUserId': null,
        'user': null,
      };
    }
  }

  /// Clear authentication data
  Future<void> clearAuthState() async {
    try {
      await prefs.remove('auth_is_authenticated');
      await prefs.remove('auth_user_id');
      await prefs.remove('auth_firebase_user_id');
      await prefs.remove('auth_user_data');
      if (kDebugMode) print('🗑️ Authentication state cleared');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to clear auth state: $e');
    }
  }

  // MARK: - Step Tracking Data
  
  /// Save step tracking data
  Future<void> saveStepData({
    required int dailySteps,
    required int totalSteps,
    required int sessionSteps,
    required DateTime lastDate,
    bool? notificationsEnabled,
  }) async {
    try {
      await prefs.setInt('steps_daily', dailySteps);
      await prefs.setInt('steps_total', totalSteps);
      await prefs.setInt('steps_session', sessionSteps);
      await prefs.setString('steps_last_date', lastDate.toIso8601String());
      
      if (notificationsEnabled != null) {
        await prefs.setBool('steps_notifications_enabled', notificationsEnabled);
      }
      
      if (kDebugMode) print('💾 Step data saved: daily=$dailySteps, total=$totalSteps');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to save step data: $e');
    }
  }

  /// Load step tracking data
  Map<String, dynamic> loadStepData() {
    try {
      final dailySteps = prefs.getInt('steps_daily') ?? 0;
      final totalSteps = prefs.getInt('steps_total') ?? 0;
      final sessionSteps = prefs.getInt('steps_session') ?? 0;
      final lastDateString = prefs.getString('steps_last_date');
      final notificationsEnabled = prefs.getBool('steps_notifications_enabled') ?? false;
      
      DateTime lastDate = DateTime.now();
      if (lastDateString != null) {
        lastDate = DateTime.tryParse(lastDateString) ?? DateTime.now();
      }
      
      if (kDebugMode) print('📖 Step data loaded: daily=$dailySteps, total=$totalSteps');
      
      return {
        'dailySteps': dailySteps,
        'totalSteps': totalSteps,
        'sessionSteps': sessionSteps,
        'lastDate': lastDate,
        'notificationsEnabled': notificationsEnabled,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Failed to load step data: $e');
      return {
        'dailySteps': 0,
        'totalSteps': 0,
        'sessionSteps': 0,
        'lastDate': DateTime.now(),
        'notificationsEnabled': false,
      };
    }
  }

  /// Save step history for a specific date
  Future<void> saveStepHistory(DateTime date, int steps) async {
    try {
      final dateKey = 'step_history_${date.year}_${date.month}_${date.day}';
      await prefs.setInt(dateKey, steps);
      
      // Also maintain a list of saved dates for easy retrieval
      final savedDates = prefs.getStringList('step_history_dates') ?? <String>[];
      final dateString = '${date.year}-${date.month}-${date.day}';
      if (!savedDates.contains(dateString)) {
        savedDates.add(dateString);
        await prefs.setStringList('step_history_dates', savedDates);
      }
      
      if (kDebugMode) print('💾 Step history saved: $dateString = $steps');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to save step history: $e');
    }
  }

  /// Load step history
  Future<Map<String, int>> loadStepHistory({int? maxDays}) async {
    try {
      final savedDates = prefs.getStringList('step_history_dates') ?? <String>[];
      final history = <String, int>{};
      
      // Limit the number of days if specified
      final datesToLoad = maxDays != null && savedDates.length > maxDays 
          ? savedDates.sublist(savedDates.length - maxDays)
          : savedDates;
      
      for (final dateString in datesToLoad) {
        final parts = dateString.split('-');
        if (parts.length == 3) {
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);
          final dateKey = 'step_history_${year}_${month}_$day';
          final steps = prefs.getInt(dateKey) ?? 0;
          history[dateString] = steps;
        }
      }
      
      if (kDebugMode) print('📖 Step history loaded: ${history.length} days');
      return history;
    } catch (e) {
      if (kDebugMode) print('❌ Failed to load step history: $e');
      return {};
    }
  }

  // MARK: - Game State Data
  
  /// Save game session data
  Future<void> saveGameSession({
    required bool isGameActive,
    String? currentUserId,
    GameUser? currentUser,
    int? lastStepCount,
    DateTime? lastSyncTime,
  }) async {
    try {
      await prefs.setBool('game_is_active', isGameActive);
      
      if (currentUserId != null) {
        await prefs.setString('game_current_user_id', currentUserId);
      } else {
        await prefs.remove('game_current_user_id');
      }
      
      if (currentUser != null) {
        await prefs.setString('game_current_user', jsonEncode(currentUser.toMap()));
      } else {
        await prefs.remove('game_current_user');
      }
      
      if (lastStepCount != null) {
        await prefs.setInt('game_last_step_count', lastStepCount);
      }
      
      if (lastSyncTime != null) {
        await prefs.setString('game_last_sync_time', lastSyncTime.toIso8601String());
      }
      
      if (kDebugMode) print('💾 Game session saved: active=$isGameActive, userId=$currentUserId');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to save game session: $e');
    }
  }

  /// Load game session data
  Map<String, dynamic> loadGameSession() {
    try {
      final isGameActive = prefs.getBool('game_is_active') ?? false;
      final currentUserId = prefs.getString('game_current_user_id');
      final currentUserJson = prefs.getString('game_current_user');
      final lastStepCount = prefs.getInt('game_last_step_count') ?? 0;
      final lastSyncTimeString = prefs.getString('game_last_sync_time');
      
      GameUser? currentUser;
      if (currentUserJson != null) {
        final userData = jsonDecode(currentUserJson) as Map<String, dynamic>;
        currentUser = GameUser.fromMap(userData);
      }
      
      DateTime? lastSyncTime;
      if (lastSyncTimeString != null) {
        lastSyncTime = DateTime.tryParse(lastSyncTimeString);
      }
      
      if (kDebugMode) print('📖 Game session loaded: active=$isGameActive, userId=$currentUserId');
      
      return {
        'isGameActive': isGameActive,
        'currentUserId': currentUserId,
        'currentUser': currentUser,
        'lastStepCount': lastStepCount,
        'lastSyncTime': lastSyncTime,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Failed to load game session: $e');
      return {
        'isGameActive': false,
        'currentUserId': null,
        'currentUser': null,
        'lastStepCount': 0,
        'lastSyncTime': null,
      };
    }
  }

  /// Clear game session data
  Future<void> clearGameSession() async {
    try {
      await prefs.remove('game_is_active');
      await prefs.remove('game_current_user_id');
      await prefs.remove('game_current_user');
      await prefs.remove('game_last_step_count');
      await prefs.remove('game_last_sync_time');
      if (kDebugMode) print('🗑️ Game session cleared');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to clear game session: $e');
    }
  }

  // MARK: - User Preferences
  
  /// Save user preferences
  Future<void> saveUserPreferences({
    bool? darkMode,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? notificationsEnabled,
    String? language,
  }) async {
    try {
      if (darkMode != null) {
        await prefs.setBool('pref_dark_mode', darkMode);
      }
      if (soundEnabled != null) {
        await prefs.setBool('pref_sound_enabled', soundEnabled);
      }
      if (vibrationEnabled != null) {
        await prefs.setBool('pref_vibration_enabled', vibrationEnabled);
      }
      if (notificationsEnabled != null) {
        await prefs.setBool('pref_notifications_enabled', notificationsEnabled);
      }
      if (language != null) {
        await prefs.setString('pref_language', language);
      }
      
      if (kDebugMode) print('💾 User preferences saved');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to save user preferences: $e');
    }
  }

  /// Load user preferences
  Map<String, dynamic> loadUserPreferences() {
    try {
      return {
        'darkMode': prefs.getBool('pref_dark_mode') ?? true,
        'soundEnabled': prefs.getBool('pref_sound_enabled') ?? true,
        'vibrationEnabled': prefs.getBool('pref_vibration_enabled') ?? true,
        'notificationsEnabled': prefs.getBool('pref_notifications_enabled') ?? true,
        'language': prefs.getString('pref_language') ?? 'en',
      };
    } catch (e) {
      if (kDebugMode) print('❌ Failed to load user preferences: $e');
      return {
        'darkMode': true,
        'soundEnabled': true,
        'vibrationEnabled': true,
        'notificationsEnabled': true,
        'language': 'en',
      };
    }
  }

  // MARK: - App State
  
  /// Save app state data
  Future<void> saveAppState({
    bool? firstLaunch,
    bool? onboardingCompleted,
    String? appVersion,
    DateTime? lastAppOpen,
    int? launchCount,
  }) async {
    try {
      if (firstLaunch != null) {
        await prefs.setBool('app_first_launch', firstLaunch);
      }
      if (onboardingCompleted != null) {
        await prefs.setBool('app_onboarding_completed', onboardingCompleted);
      }
      if (appVersion != null) {
        await prefs.setString('app_version', appVersion);
      }
      if (lastAppOpen != null) {
        await prefs.setString('app_last_open', lastAppOpen.toIso8601String());
      }
      if (launchCount != null) {
        await prefs.setInt('app_launch_count', launchCount);
      }
      
      if (kDebugMode) print('💾 App state saved');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to save app state: $e');
    }
  }

  /// Load app state data
  Map<String, dynamic> loadAppState() {
    try {
      return {
        'firstLaunch': prefs.getBool('app_first_launch') ?? true,
        'onboardingCompleted': prefs.getBool('app_onboarding_completed') ?? false,
        'appVersion': prefs.getString('app_version'),
        'lastAppOpen': prefs.getString('app_last_open') != null 
            ? DateTime.tryParse(prefs.getString('app_last_open')!)
            : null,
        'launchCount': prefs.getInt('app_launch_count') ?? 0,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Failed to load app state: $e');
      return {
        'firstLaunch': true,
        'onboardingCompleted': false,
        'appVersion': null,
        'lastAppOpen': null,
        'launchCount': 0,
      };
    }
  }

  // MARK: - Utility Methods
  
  /// Clear all app data (for logout or reset)
  Future<void> clearAllData() async {
    try {
      await clearAuthState();
      await clearGameSession();
      
      // Clear ALL step data on logout
      await prefs.remove('steps_daily');
      await prefs.remove('steps_total');
      await prefs.remove('steps_session');
      await prefs.remove('steps_last_date');
      await prefs.remove('steps_notifications_enabled');
      
      // Clear step history as well for complete logout
      final savedDates = prefs.getStringList('step_history_dates') ?? <String>[];
      for (final dateString in savedDates) {
        final parts = dateString.split('-');
        if (parts.length == 3) {
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);
          final dateKey = 'step_history_${year}_${month}_$day';
          await prefs.remove(dateKey);
        }
      }
      await prefs.remove('step_history_dates');
      
      if (kDebugMode) print('🗑️ All user data and step data cleared on logout');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to clear all data: $e');
    }
  }

  /// Check if this is the first app launch
  bool isFirstLaunch() {
    return prefs.getBool('app_first_launch') ?? true;
  }

  /// Increment launch count and update last open time
  Future<void> recordAppLaunch() async {
    try {
      final launchCount = prefs.getInt('app_launch_count') ?? 0;
      await prefs.setInt('app_launch_count', launchCount + 1);
      await prefs.setString('app_last_open', DateTime.now().toIso8601String());
      await prefs.setBool('app_first_launch', false);
      
      if (kDebugMode) print('📱 App launch recorded: ${launchCount + 1}');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to record app launch: $e');
    }
  }

  /// Export all data for debugging
  Map<String, dynamic> exportAllData() {
    try {
      final allKeys = prefs.getKeys();
      final data = <String, dynamic>{};
      
      for (final key in allKeys) {
        final value = prefs.get(key);
        data[key] = value;
      }
      
      if (kDebugMode) print('📤 Exported ${data.length} data keys');
      return data;
    } catch (e) {
      if (kDebugMode) print('❌ Failed to export data: $e');
      return {};
    }
  }
}
