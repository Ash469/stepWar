StepWars Flutter App
====================

A gamified fitness App where your daily steps fuel real-time battles against friends and bots.

🎮 Features
-----------

### Core Gameplay

-   **Real-time Step Tracking**: Utilizes the device's pedometer for live step counting.

-   **1v1 Battles**: Challenge friends with a unique game ID or take on bots for a quick match.

-   **Dynamic Score System**: Steps are converted into points, which can be amplified with in-game multipliers (1.5x, 2x, 3x).

-   **Multiple Win Conditions**: Win by having the highest score at the end of the 10-minute timer, or achieve an instant "KO" by leading your opponent by 200 points.

-   **Friend Battle**: Invite your friend to a duel with your unique battle code.

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

### UI/UX Design

-   **Dark Theme**: A modern, sleek design with a dark background and vibrant, high-contrast UI elements.

-   **Smooth Onboarding**: A multi-page onboarding flow introduces new users to the core concepts of the game.

-   **Clean Dashboards**: Intuitive home and profile screens that provide at-a-glance information about steps and user stats.

-   **Responsive Design**: The interface is optimized for a seamless experience on various mobile devices.

## ⚙️ Technical Features

### Hybrid Backend Architecture
A scalable backend built with **Node.js** and **Express**, deployed on **AWS Elastic Beanstalk**.  
Uses **MongoDB** for persistent data storage (user profiles, rewards, battle history) and integrates **Firebase** for specific functionalities.

### Firebase Integration
- **Authentication**: Secure user sign-up/sign-in via **Firebase Authentication** (Google Sign-In).  
- **Realtime Battles**: Uses **Firebase Realtime Database** to sync live battle data (scores, steps, multipliers) with minimal latency.  
- **Push Notifications**: **Firebase Cloud Messaging (FCM)** delivers real-time notifications for battle outcomes and key events.

### Pedometer Integration
Efficient, low-battery step tracking using native device sensors via the **pedometer** package.  
Step data is synchronized with the backend to ensure accuracy and prevent inconsistencies.

### State Management
Combines **Flutter’s StatefulWidget** for local UI state and **Provider** for global app state management.  
Example: `ActiveBattleService` maintains live battle state across different screens.

### Modular Service Layer
Follows a clean separation of concerns with a robust service layer.  
Dedicated services handle:
- **AuthService** → Authentication  
- **GameService** → Game logic  
- **BotService** → Bot intelligence  
- **ActiveBattleService** → Live battle state  
- **NotificationService** → Push notifications  
- **MysteryBoxService** → Reward systems  

---


🏗️ Project Structure
---------------------

```
lib/
├── main.dart # App entry point
├── models/
│ ├── user_model.dart # Data model for user profiles and stats
│ └── battle_RB.dart # Data model for live battle data in Realtime DB
├── screens/
│ ├── main_screen.dart # Main navigation hub with bottom nav bar
│ ├── home_screen.dart # Dashboard to start battles and view stats
│ ├── battle_screen.dart # Real-time battle UI
│ ├── matchmaking_screen.dart # UI for finding online opponents
│ ├── waiting_for_friend_screen.dart # Lobby for private friend battles
│ ├── kingdom_screen.dart # Displays user's collected rewards
│ ├── profile_screen.dart # User profile, settings, and activity history
│ ├── login_screen.dart # Authentication screen
│ └── onboarding_screen.dart # First-time user introduction
├── services/
│ ├── auth_service.dart # Handles user sign-in, sign-out, and profile data
│ ├── game_service.dart # API calls for creating/ending battles
│ ├── active_battle_service.dart # Manages live battle state with Provider
│ ├── bot_service.dart # Logic for bot opponent behavior
│ ├── notification_service.dart # Manages FCM token registration and notifications
│ ├── mystery_box_service.dart # Handles logic for opening reward boxes
│ └── step_counting.dart # Manages hardware pedometer integration
└── theme/
└── widget/
├── game_rules.dart # Reusable game rules widget
└── footer.dart # App footer widget
```


🚀 Getting Started
------------------

### Prerequisites

-   Flutter SDK 3.0.0 or higher

-   Dart 2.17.0 or higher

-   An IDE like Android Studio or VS Code with Flutter extensions.

-   A Firebase project set up with Authentication, Firestore, and Realtime Database enabled.

### Installation

1.  **Clone the repository**

    ```
    git clone <repository-url>
    cd stepwars_flutter_app

    ```

2.  **Set up Firebase**

    -   Follow the official FlutterFire documentation to add your `google-services.json` (for Android) and `GoogleService-Info.plist` (for iOS) to the project.

3.  **Install dependencies**

    ```
    flutter pub get

    ```

4.  **Run the app**

    ```
    flutter run

    ```

🎯 Game Mechanics
-----------------

### Battle Rules

-   **Duration**: Each battle lasts for 10 minutes.

-   **Objective**: Get a higher score than your opponent. Your score is your step count, amplified by any active multipliers.

-   **KO Victory**: Instantly win the game if your score lead becomes 200 or more.

-   **Timed Victory**: If no KO occurs, the player with the higher score at the end of 10 minutes wins.

-   **Draw**: If the score difference is 50 or less when the timer ends, the game is a draw.


### Multipliers

-   Players can activate a 1.5x, 2x, or 3x multiplier at any time.

-   Once activated, every subsequent step taken contributes more points to the player's total score.

-   Only the player's own multiplier affects their score.


**StepWars** - Outwalk the competition! 🚀