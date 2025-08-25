# StepWars Flutter App

A gamified fitness MVP where steps are converted into attacks and shields for territorial conquest.

## 🎮 Features

### Core Gameplay
- **Step Tracking**: Advanced step detection with activity recognition and cadence validation
- **Territory System**: Conquer and defend territories with shield-based combat
- **Real-time Battles**: Live tussle view with 3D animations and effects
- **Progressive War**: Shield damage persists across days

### UI/UX Design
- **Dark Theme**: Epic, futuristic design with war game aesthetics
- **3D Animations**: Rotating step counters, particle effects, and battle animations
- **Micro-interactions**: Button animations, progress bar transitions, and haptic feedback
- **Responsive Design**: Optimized for mobile devices with touch support

### Technical Features
- **Smart Step Detection**: Layered filtering with activity recognition and bout validation
- **State Management**: Provider pattern for reactive UI updates
- **Mock Data**: Comprehensive dummy data for testing and demonstration
- **Modular Architecture**: Clean separation of concerns with services and widgets

## 🏗️ Project Structure

```
lib/
├── main.dart                 # App entry point and navigation
├── theme/
│   └── app_theme.dart       # Dark theme and color palette
├── models/
│   ├── territory.dart       # Territory data model
│   └── user_stats.dart      # User statistics model
├── screens/
│   ├── my_territory_screen.dart  # User's territory management
│   └── world_screen.dart         # Global territory list and attacks
├── widgets/
│   ├── animated_progress_bar.dart # Animated shield/health bars
│   ├── territory_card.dart        # Territory display component
│   ├── status_pill.dart           # Status indicator widget
│   ├── step_counter_3d.dart       # 3D animated step counter
│   └── battle_tussle_view.dart    # Real-time battle interface
├── services/
│   └── step_tracking_service.dart # Advanced step detection
└── data/
    └── mock_data.dart             # Dummy data for testing
```

## 🎨 Design System

### Color Palette
- **Background**: Dark gray/black (#121212, #1E1E1E)
- **Attack**: Red (#E53935)
- **Defense**: Blue (#1E88E5)
- **Success**: Gold (#FFD700) / Green (#43A047)
- **Warning**: Orange (#FB8C00)
- **Text**: White (#FFFFFF) / Light gray (#B0BEC5)

### Typography
- **Headings**: Roboto Bold
- **Body**: Roboto Regular
- **Numbers**: Roboto Mono (for step counts and stats)

### Components
- **Cards**: Rounded corners (16dp), colored borders, soft shadows
- **Progress Bars**: Animated with shimmer effects
- **Buttons**: Large, rounded with icons and haptic feedback
- **Status Pills**: Color-coded with animations

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.16.9 or higher
- Dart 3.0.0 or higher
- Android Studio / VS Code with Flutter extensions

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd stepwars_flutter/stepwars_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # UI & Animation
  cupertino_icons: ^1.0.2
  flutter_animate: ^4.2.0
  rive: ^0.11.4
  lottie: ^2.6.0
  
  # State Management
  provider: ^6.0.5
  
  # Sensors & Step Tracking
  sensors_plus: ^3.1.0
  pedometer: ^3.0.0
  permission_handler: ^11.0.1
  
  # Firebase (for production)
  firebase_core: ^2.15.1
  firebase_auth: ^4.9.0
  cloud_firestore: ^4.9.1
  firebase_messaging: ^14.6.7
  
  # Utils
  shared_preferences: ^2.2.1
  intl: ^0.18.1
```

## 🎯 Game Mechanics

### Step Economy
- **100 steps** = 1 Attack Point
- **10 Attack Points** = 1 Shield Hit
- **100 steps** = +1 Shield Point (when defending)

### Territory Rules
- Each territory has a shield level (hits remaining to capture)
- Only one attacker can focus a territory at a time
- Shield damage persists across days
- 24-hour cooldown after capture
- Maximum 3 attacks per day per user

### Battle Flow
1. **Attack Initiation**: Player selects territory and attack power
2. **Tussle Phase**: Real-time battle with step conversion
3. **Defense Response**: Owner can reinforce shields
4. **Resolution**: Territory captured if shield reaches 0

## 🔧 Step Tracking Algorithm

The app implements a sophisticated step detection system:

### Layered Filtering
1. **Sensor Selection**: Prefers TYPE_STEP_DETECTOR over raw accelerometer
2. **Activity Gating**: Only counts steps during WALKING/RUNNING states
3. **Bout Validation**: Requires 6 consecutive steps at plausible cadence
4. **Cadence Window**: Enforces 40-220 steps/minute range
5. **Anomaly Filters**: Rejects vehicle spikes and shake bursts

### Configuration
- **Consecutive Steps**: 6 steps to start bout
- **Cadence Range**: 40-220 steps per minute
- **Idle Timeout**: 3 seconds to end bout
- **Vehicle Lockout**: 10 seconds after vehicle detection

## 📱 Screens Overview

### My Territory Screen
- **3D Step Counter**: Animated with rotating rings and particles
- **Territory Management**: Shield status and reinforcement options
- **Battle Statistics**: Wins, losses, and daily attack limits
- **Step Conversion**: Real-time attack/shield point calculation

### World Screen
- **Territory List**: Filterable list of all territories
- **Attack Interface**: Territory selection and power allocation
- **Status Indicators**: Real-time battle states and cooldowns
- **Quick Attack**: Fast access to available targets

### Battle Tussle View
- **Real-time Combat**: Live shield updates and animations
- **Step Conversion**: Convert steps to attacks or shields
- **Visual Effects**: Missiles, explosions, and energy fields
- **Progress Tracking**: Shield health and battle statistics

## 🎨 Animations & Effects

### 3D Step Counter
- **Rotating Rings**: Multiple layers with different speeds
- **Particle System**: Floating energy particles
- **Pulse Effects**: Scale animations on step updates
- **Color Gradients**: Dynamic color transitions

### Battle Animations
- **Missile Attacks**: Projectile animations with trails
- **Shield Effects**: Pulsing defensive barriers
- **Explosion Effects**: Radial burst animations
- **Territory Shake**: Vibration effects during attacks

### Micro-interactions
- **Button Press**: Scale down with ripple effects
- **Progress Bars**: Smooth transitions with shimmer
- **Card Hover**: Elevation and glow effects
- **Status Changes**: Color transitions and icon swaps

## 🔮 Future Enhancements

### Planned Features
- **Firebase Integration**: Real-time multiplayer battles
- **Push Notifications**: Attack alerts and battle updates
- **Advanced Analytics**: Battle statistics and performance tracking
- **Social Features**: Friend lists and leaderboards
- **Territory Expansion**: More locations and special territories

### Technical Improvements
- **Performance Optimization**: Reduced animation overhead
- **Battery Efficiency**: Optimized step tracking algorithms
- **Offline Support**: Local data caching and sync
- **Accessibility**: Screen reader support and high contrast mode

## 📄 License

This project is proprietary software. All rights reserved.

## 🤝 Contributing

This is a client project. Contributions are managed through the development team.

## 📞 Support

For technical support or questions, contact the development team.

---

**StepWars** - Where every step counts in the battle for territorial supremacy! 🚀⚔️

