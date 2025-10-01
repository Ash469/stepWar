StepWars Flutter App
====================

A gamified fitness App where your daily steps fuel real-time battles against friends and bots.

🎮 Features
-----------

### Core Gameplay

-   **Real-time Step Tracking**: Utilizes the device's pedometer for live step counting.

-   **1v1 Battles**: Challenge friends with a unique game ID or take on bots for a quick match.

-   **Dynamic Score System**: Steps are converted into points, which can be amplified with in-game multipliers (1.5x, 2x, 3x).

-   **Multiple Win Conditions**: Win by having the highest score at the end of the 60-minute timer, or achieve an instant "KO" by leading your opponent by 3000 points.

-   **Forfeit Handling**: Players who leave an ongoing match will automatically lose, ensuring fair play.

### UI/UX Design

-   **Dark Theme**: A modern, sleek design with a dark background and vibrant, high-contrast UI elements.

-   **Smooth Onboarding**: A multi-page onboarding flow introduces new users to the core concepts of the game.

-   **Clean Dashboards**: Intuitive home and profile screens that provide at-a-glance information about steps and user stats.

-   **Responsive Design**: The interface is optimized for a seamless experience on various mobile devices.

### Technical Features

-   **Firebase Backend**: Uses Firebase Authentication for email and Google Sign-In, Cloud Firestore for user profiles, and Realtime Database for live battle data.

-   **Pedometer Integration**: Leverages the `pedometer` package for efficient, low-battery step tracking.

-   **Stateful Management**: Built with Flutter's core `StatefulWidget` and `setState` for reactive UI updates.

-   **Modular Architecture**: A clean separation of concerns with dedicated services for authentication, game logic, and step counting.

🏗️ Project Structure
---------------------

```
lib/
├── main.dart
├── models/
│   ├── user_model.dart           # User profile data model (Firestore)
│   └── battle_RB.dart            # Real-time battle data model (Realtime DB)
├── screens/
│   ├── home_screen.dart          # Main dashboard for starting battles
│   ├── battle_screen.dart        # Real-time battle interface
│   ├── kingdom_screen.dart       # Gallery for collected items/rewards
│   ├── profile_screen.dart       # User profile and statistics
│   ├── login_screen.dart         # User authentication
│   └── onboarding_screen.dart    # Introduction for new users
├── services/
│   ├── auth_service.dart         # Handles user authentication
│   ├── game_service.dart         # Manages battle creation and state
│   ├── bot_service.dart          # Logic for bot opponents
│   └── step_counting.dart      # Manages pedometer integration
└── ... (other widgets and assets)

```

🎨 Design System
----------------

### Color Palette

-   **Background**: Dark Gray/Black (#121212, #1E1E1E)

-   **Primary/Accent**: Yellow (#FDD85D, #FFC107)

-   **Error/Danger**: Red (#E53935)

-   **Positive**: Green (#69F0AE)

-   **Text**: White (#FFFFFF) / Light Gray (#B0BEC5)

### Typography

-   **Headings & UI**: Montserrat

-   **Body**: Default platform fonts

### Components

-   **Cards**: Rounded corners (12dp-16dp) with dark backgrounds.

-   **Buttons**: Large, rounded with vibrant accent colors.

-   **Dialogs**: Custom-styled dialogs for game over and leave battle confirmations.

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

### Dependencies

```
dependencies:
  flutter:
    sdk: flutter

  # UI
  cupertino_icons: ^1.0.2

  # Firebase
  firebase_core: ^2.24.2
  firebase_auth: ^4.16.0
  cloud_firestore: ^4.14.0
  firebase_database: ^10.4.0 # For real-time battles
  google_sign_in: ^6.2.1

  # Sensors & Permissions
  pedometer: ^4.0.1
  permission_handler: ^11.3.0

  # Utils
  shared_preferences: ^2.2.2
  intl: ^0.19.0

```

🎯 Game Mechanics
-----------------

### Battle Rules

-   **Duration**: Each battle lasts for 60 minutes.

-   **Objective**: Get a higher score than your opponent. Your score is your step count, amplified by any active multipliers.

-   **KO Victory**: Instantly win the game if your score lead becomes 3000 or more.

-   **Timed Victory**: If no KO occurs, the player with the higher score at the end of 60 minutes wins.

-   **Draw**: If the score difference is 100 or less when the timer ends, the game is a draw.

-   **Forfeit**: Leaving a battle before it concludes results in an automatic loss.

### Multipliers

-   Players can activate a 1.5x, 2x, or 3x multiplier at any time.

-   Once activated, every subsequent step taken contributes more points to the player's total score.

-   Only the player's own multiplier affects their score.

📱 Screens Overview
-------------------

### Home Screen

-   Displays the user's daily step count.

-   Provides options to start an "Online Battle" (against a bot) or "Battle a Friend" (PvP).

-   Shows a summary of battle stats and game rules.

### Battle Screen

-   Displays both players' scores and multipliers in real-time.

-   Features a countdown timer for the 60-minute duration.

-   An animated "Battle Bar" visualizes the current score difference between players.

-   Allows players to select and activate score multipliers.

### Kingdom Screen

-   A gallery view showcasing collectible items or rewards that can be earned.

-   (Note: The logic for earning these items is a future enhancement.)

### Profile Screen

-   Shows user details like username, email, and other personal stats.

-   Includes a chart to visualize step history over the last 7 days.

-   Allows users to edit their profile information and set a daily step goal.

**StepWars** - Outwalk the competition! 🚀