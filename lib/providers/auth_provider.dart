import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/persistence_service.dart';
import '../services/firebase_sync_service.dart';
import '../services/firestore_service.dart';

enum AuthState {
  unknown,
  unauthenticated,
  authenticated,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final PersistenceService _persistence = PersistenceService();
  final FirebaseStepSyncService _firebaseSyncService = FirebaseStepSyncService();
  
  AuthState _authState = AuthState.unknown;
  GameUser? _currentUser;
  String? _errorMessage;
  bool _isLoading = false;

  // Getters
  AuthState get authState => _authState;
  GameUser? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _authState == AuthState.authenticated;

  AuthProvider() {
    _initializeAuthState();
  }

  /// Initialize authentication state and listen to changes
  Future<void> _initializeAuthState() async {
    _setLoading(true);
    
    try {
      // Initialize persistence service
      await _persistence.initialize();
      
      // Load persisted auth state first
      _loadPersistedAuthState();
      
      // Initialize AuthService
      await _authService.initialize();
      
      // Listen to Firebase Auth state changes
      _authService.authStateChanges.listen(_onAuthStateChanged);
      
      // Check current auth state against Firebase
      await _checkAuthState();
    } catch (e) {
      _setError('Failed to initialize authentication: $e');
      _authState = AuthState.unauthenticated;
    } finally {
      _setLoading(false);
    }
  }

  /// Handle Firebase Auth state changes
  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
      _authState = AuthState.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      // Add a small delay to allow profile creation to complete
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Get user profile from database
      final userProfile = await _authService.getUserProfile(firebaseUser.uid);
      
      if (userProfile != null) {
        _currentUser = userProfile;
        _authState = AuthState.authenticated;
        
        // Load user-specific data from Firebase
        await _loadUserSpecificData(firebaseUser.uid);
        
        // Persist the authentication state
        await _persistAuthState();
      } else {
        // Profile should have been created during sign-in, but if it doesn't exist,
        // we'll set authenticated state anyway since Google auth was successful
        // We can show a fallback name from Firebase user data
        _authState = AuthState.authenticated;
        await _persistAuthState();
        print('No user profile found, but Firebase user is authenticated');
      }
    } catch (e) {
      print('Error in auth state changed: $e');
      // Don't fail authentication just because profile loading failed
      _authState = AuthState.authenticated;
      await _persistAuthState();
    }
    
    notifyListeners();
  }

  /// Check current authentication state
  Future<void> _checkAuthState() async {
    final firebaseUser = _authService.currentUser;
    
    if (firebaseUser == null) {
      _authState = AuthState.unauthenticated;
      return;
    }

    try {
      // Load user profile
      final userProfile = await _authService.getUserProfile(firebaseUser.uid);
      if (userProfile != null) {
        _currentUser = userProfile;
        _authState = AuthState.authenticated;
        await _persistAuthState();
      } else {
        // If no profile exists, user is still authenticated but profile will be created
        _authState = AuthState.authenticated;
        await _persistAuthState();
      }
    } catch (e) {
      _setError('Failed to check authentication state: $e');
      _authState = AuthState.unauthenticated;
      await _persistAuthState();
    }
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _clearError();
    
    try {
      final userCredential = await _authService.signInWithGoogle();
      
      if (userCredential == null) {
        // User cancelled sign-in
        return false;
      }

      // Auth state will be updated by the stream listener
      return true;
    } catch (e) {
      _setError('Failed to sign in with Google: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }


  /// Update user profile
  Future<bool> updateUserProfile(GameUser updatedUser) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _authService.updateUserProfile(updatedUser);
      _currentUser = updatedUser;
      await _persistAuthState();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update profile: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _setLoading(true);
    _clearError();
    
    try {
      // Clear all user data from local storage first
      await _persistence.clearAllData();
      
      // Clear Firebase sync service data
      await _firebaseSyncService.clearUserData();
      
      // Sign out from Firebase
      await _authService.signOut();
      
      _currentUser = null;
      _authState = AuthState.unauthenticated;
      
      if (kDebugMode) print('🗑️ Complete sign out with data clearing completed');
    } catch (e) {
      _setError('Failed to sign out: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh user data
  Future<void> refreshUserData() async {
    if (_authService.currentUser == null) return;
    
    try {
      final userProfile = await _authService.getUserProfile(_authService.currentUser!.uid);
      if (userProfile != null) {
        _currentUser = userProfile;
        await _persistAuthState();
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to refresh user data: $e');
      }
    }
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    if (kDebugMode) {
      print('Auth Error: $error');
    }
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Load user-specific data from Firebase after authentication
  Future<void> _loadUserSpecificData(String userId) async {
    try {
      if (kDebugMode) print('📊 Loading user-specific data for user: $userId');
      
      // First, fetch or create user in Firestore
      final firebaseUser = _authService.currentUser;
      if (firebaseUser != null) {
        final firestoreService = FirestoreService();
        
        // Load step data from Firebase Realtime Database (for migration)
        int? existingSteps;
        final firebaseStepData = await _firebaseSyncService.getStepsFromFirebase(userId);
        if (firebaseStepData != null) {
          existingSteps = firebaseStepData['total_steps'] ?? 0;
          if (kDebugMode) {
            print('🎯 [Auth] Found existing steps in RTDB: $existingSteps');
          }
        }
        
        // Fetch or create user in Firestore with existing steps
        final firestoreUser = await firestoreService.fetchOrCreateUser(
          firebaseUser,
          existingSteps: existingSteps,
        );
        
        if (firestoreUser != null) {
          // Display user data in console for debugging
          firestoreService.displayUserData(firestoreUser);
          
          // Get and display user stats summary
          final statsSummary = firestoreService.getUserStatsSummary(firestoreUser);
          if (kDebugMode) {
            print('📈 [Auth] User Stats Summary:');
            print(statsSummary);
          }
          
          // Update the current user with Firestore data if needed
          if (_currentUser == null || _currentUser!.id != firestoreUser.id) {
            _currentUser = firestoreUser;
            notifyListeners();
            if (kDebugMode) {
              print('✅ [Auth] Updated current user with Firestore data');
            }
          }
        } else {
          if (kDebugMode) {
            print('⚠️ [Auth] Failed to fetch or create Firestore user, continuing with existing user data');
          }
        }
        
        // Load step data from Firebase and update local storage
        if (firebaseStepData != null) {
          final todaySteps = firebaseStepData['today_steps'] ?? 0;
          final totalSteps = firebaseStepData['total_steps'] ?? 0;
          
          // Save the Firebase data to local storage
          await _persistence.saveStepData(
            dailySteps: todaySteps,
            totalSteps: totalSteps,
            sessionSteps: 0,
            lastDate: DateTime.now(),
            notificationsEnabled: true,
          );
          
          if (kDebugMode) {
            print('📈 Loaded user step data - Today: $todaySteps, Total: $totalSteps');
          }
        }
      }
      
      if (kDebugMode) print('✅ User-specific data loaded successfully');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to load user-specific data: $e');
      // Don't throw error - authentication should still succeed
    }
  }

  // MARK: - Persistence Methods

  /// Load persisted authentication state
  void _loadPersistedAuthState() {
    try {
      final authData = _persistence.loadAuthState();
      final wasAuthenticated = authData['isAuthenticated'] as bool;
      final user = authData['user'] as GameUser?;
      
      if (wasAuthenticated && user != null) {
        _currentUser = user;
        _authState = AuthState.authenticated;
        if (kDebugMode) print('📖 Restored authentication state for user: ${user.nickname}');
      } else {
        _authState = AuthState.unauthenticated;
        if (kDebugMode) print('📖 No valid authentication state found');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to load persisted auth state: $e');
      _authState = AuthState.unauthenticated;
    }
  }

  /// Persist current authentication state
  Future<void> _persistAuthState() async {
    try {
      await _persistence.saveAuthState(
        isAuthenticated: _authState == AuthState.authenticated,
        userId: _currentUser?.id,
        firebaseUserId: _authService.currentUser?.uid,
        user: _currentUser,
      );
    } catch (e) {
      if (kDebugMode) print('❌ Failed to persist auth state: $e');
    }
  }
}
