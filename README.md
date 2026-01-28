# StepWars Flutter App

A gamified fitness app where your daily steps fuel real-time battles against friends and bots.

## 🎮 Features

### Core Gameplay
- **Real-time Step Tracking**: Utilizes the device's pedometer for live step counting
- **1v1 Battles**: Challenge friends with a unique game ID or take on bots for a quick match
- **Dynamic Score System**: Steps are converted into points, amplified with in-game multipliers (1.5x, 2x, 3x)
- **Multiple Win Conditions**: Win by highest score at the end of 10 minutes, or achieve an instant "KO" by leading by 200 points
- **Friend Battle**: Invite friends to a duel with your unique battle code

### Reward System
**Reward Types**
- Forts → famous cities/regions
- Monuments → global landmarks
- Legends → historical/present figures
- Badges → themes, causes, fanbases

**Tiers & Rates**
- Rare – 60%
- Epic – 25%
- Mythic – 12%
- Legendary – 3%

Each online battle win grants exactly one random reward.

---

## ⚙️ Technical Architecture

### Hybrid Backend Architecture
A scalable backend built with **Node.js** and **Express**, deployed on **AWS Elastic Beanstalk**.  
Uses **MongoDB** for persistent data storage (user profiles, rewards, battle history) and integrates **Firebase** for specific functionalities.

### Firebase Integration
- **Authentication**: Secure user sign-up/sign-in via **Firebase Authentication** (Google Sign-In)
- **Realtime Battles**: Uses **Firebase Realtime Database** to sync live battle data (scores, steps, multipliers) with minimal latency
- **Push Notifications**: **Firebase Cloud Messaging (FCM)** delivers real-time notifications for battle outcomes and key events

---

## 📊 Step Tracking System


1. **Show DB Steps First**: Display steps from database until permissions and showcase complete
2. **Smart Offset Calculation**: Take `max(local_step_count, dbSteps)` as baseline when calculating offset
3. **Service Initialization**: Save `initialDbSteps` to service data before starting, ensuring service has correct baseline

**Key Files Modified**:
- `lib/screens/home_screen.dart` (lines 289-294, 791-837)
- `lib/services/step_task_handler.dart` (lines 118-141, 256-265)

### Core Step Tracking Architecture

The step tracking system uses a **"Triple Thread"** approach (Sensor → Disk → Cloud) to ensure reliable, accurate step counting:

#### 1. **HealthService** (`step_counting.dart`) - The Live Sensor
- **Purpose**: Direct hardware interface
- **Function**: Hooks into the device's pedometer sensor via the `pedometer` package
- **Output**: Live stream of step counts from the physical sensor
- **Limitation**: Only reports current count; no historical context

```dart
// Provides real-time step stream
Stream<String> get stepStream => _stepController.stream;
```

#### 2. **StepHistoryService** (`step_history_service.dart`) - The Local Database
- **Purpose**: Local audit log and backup system
- **Storage**: Saves step data as a map in SharedPreferences (`{"2024-05-20": 5400}`)
- **Key Features**:
  - **Recovery**: `recoverTodaySteps()` (L93) restores steps after app crash/restart
  - **Cleanup**: Automatically deletes data older than 30 days (L120)
  - **Validation**: Ensures date format and non-negative step values

```dart
// Example: Recover steps after crash
Future<int?> recoverTodaySteps() async {
  final todayString = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return _stepHistory[todayString];
}
```

#### 3. **StepTaskHandler** (`step_task_handler.dart`) - The Background Brain
- **Purpose**: Foreground service managing disaster recovery and synchronization
- **Key Responsibilities**:

**Reboot Detection** (L58-115):
- Detects when pedometer sensor resets (e.g., phone reboot)
- Calculates new `dailyStepOffset` to preserve user's steps
- Uses formula: `offset = currentPedometerReading - max(dbSteps, localSteps)`

**Midnight Transition** (L282):
- At 12:00 AM, performs final backup:
  - Saves final count for "yesterday" to `StepHistoryService`
  - Creates snapshot in `SharedPreferences` (`pending_past_steps`)
  - Resets daily counters for new day

**Background Syncing** (L334):
- Every 15 minutes, attempts to sync pending backups to server
- Retries failed syncs on next cycle if internet is unavailable
- Ensures no data loss during network outages

```dart
// Offset calculation with baseline protection
int baseline = _lastKnownDbSteps ?? 0;
if (_localStepCount != null && _localStepCount! > baseline) {
  baseline = _localStepCount!;
}
final int newOffset = _steps - baseline;
```

#### 4. **StepProvider** (`step_provider.dart`) - The State Manager
- **Purpose**: Single source of truth for step-related state across the app
- **Pattern**: Uses Flutter's `ChangeNotifier` for reactive UI updates
- **Key Features**:
  - **Cache-First Loading**: `_loadInitialStepsSync()` (L56) prevents "flash of zero" by loading cached steps immediately
  - **Service Communication**: Receives live updates from `StepTaskHandler` via `_onReceiveTaskData()` (L80)
  - **DB Synchronization**: `updateDbSteps()` (L105) ensures current steps never decrease below DB steps
  - **Google Fit Integration**: Manages Google Fit sync and statistics

```dart
// Prevents flash of zero on app start
void _loadInitialStepsSync() {
  SharedPreferences.getInstance().then((prefs) {
    final cachedProfile = prefs.getString('userProfile');
    // Parse and display cached steps immediately
  });
}
```

### Data Flow Summary

```
1. Pedometer Sensor (HealthService)
   ↓
2. StepTaskHandler (calculates offset, handles reboots)
   ↓
3. StepHistoryService (saves to disk every few seconds)
   ↓
4. StepProvider (notifies UI)
   ↓
5. Backend Sync (every 15 minutes or on app open)
```

---

## 🎯 Battle System

### ActiveBattleService (`active_battle_service.dart`)
- **Purpose**: Manages live battle state using Provider pattern
- **Key Features**:
  - **Real-time Sync**: Listens to Firebase Realtime Database for opponent updates
  - **Step Tracking**: Monitors `HealthService` stream during battles
  - **Bot Intelligence**: Generates realistic bot steps every 2 seconds
  - **Timer Management**: 10-minute countdown with KO detection
  - **Multiplier System**: Applies score multipliers (1.5x, 2x, 3x) in real-time
  - **Foreground Service Integration**: Sends battle state to notification

```dart
// Battle state sent to foreground service notification
FlutterForegroundTask.sendDataToTask({
  'battleActive': true,
  'myScore': myScore,
  'opponentScore': opponentScore,
  'timeLeft': '09:45',
});
```

---

## 🏗️ Project Structure

```
lib/
├── main.dart                          # App entry point
├── models/
│   ├── user_model.dart               # User profiles and stats
│   └── battle_rb.dart                # Live battle data model
├── screens/
│   ├── main_screen.dart              # Main navigation hub
│   ├── home_screen.dart              # Dashboard and battle launcher
│   ├── battle_screen.dart            # Real-time battle UI
│   ├── matchmaking_screen.dart       # Online opponent finder
│   ├── waiting_for_friend_screen.dart # Friend battle lobby
│   ├── kingdom_screen.dart           # Collected rewards display
│   ├── profile_screen.dart           # User profile and settings
│   ├── login_screen.dart             # Authentication
│   └── onboarding_screen.dart        # First-time user intro
├── providers/
│   └── step_provider.dart            # Step state management
├── services/
│   ├── auth_service.dart             # Authentication logic
│   ├── game_service.dart             # Battle API calls
│   ├── active_battle_service.dart    # Live battle state manager
│   ├── bot_service.dart              # Bot opponent behavior
│   ├── notification_service.dart     # FCM notifications
│   ├── mystery_box_service.dart      # Reward system logic
│   ├── step_counting.dart            # Pedometer integration (HealthService)
│   ├── step_task_handler.dart        # Background step tracking service
│   └── step_history_service.dart     # Local step data storage
└── widgets/
    ├── game_rules.dart               # Reusable game rules widget
    └── footer.dart                   # App footer widget
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.0.0 or higher
- Dart 2.17.0 or higher
- An IDE like Android Studio or VS Code with Flutter extensions
- A Firebase project with Authentication, Firestore, and Realtime Database enabled

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd stepwars_flutter_app
   ```

2. **Set up Firebase**
   - Follow the official FlutterFire documentation to add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

---

## 🎯 Game Mechanics

### Battle Rules
- **Duration**: Each battle lasts 10 minutes
- **Objective**: Get a higher score than your opponent (steps × multiplier)
- **KO Victory**: Instantly win if your score lead reaches 200 or more
- **Timed Victory**: Player with higher score at 10 minutes wins
- **Draw**: If score difference is 50 or less when timer ends

### Multipliers
- Players can activate 1.5x, 2x, or 3x multiplier at any time
- Once activated, all subsequent steps contribute more points
- Only the player's own multiplier affects their score

---

**StepWars** - Outwalk the competition! 🚀