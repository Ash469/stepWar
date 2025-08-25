import 'package:flutter/material.dart';

class AppTheme {
  // Color Palette from Design Guide
  static const Color backgroundDark = Color(0xFF121212);
  static const Color backgroundSecondary = Color(0xFF1E1E1E);
  static const Color primaryAttack = Color(0xFFE53935);
  static const Color primaryDefend = Color(0xFF1E88E5);
  static const Color successGold = Color(0xFFFFD700);
  static const Color successGreen = Color(0xFF43A047);
  static const Color dangerOrange = Color(0xFFFF8C00);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFFB0BEC5);
  static const Color cardShadow = Color(0x1A000000);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.red,
      scaffoldBackgroundColor: backgroundDark,
      cardColor: backgroundSecondary,
      
      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundDark,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: textWhite,
        ),
      ),
      
      // Text Theme
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.bold,
          fontSize: 32,
          color: textWhite,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.bold,
          fontSize: 24,
          color: textWhite,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: textWhite,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          color: textWhite,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          color: textGray,
        ),
        bodySmall: TextStyle(
          fontFamily: 'RobotoMono',
          fontSize: 12,
          color: textGray,
        ),
      ),

      
      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      
      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryAttack,
        linearTrackColor: backgroundSecondary,
      ),
    );
  }
}

// Custom Button Styles
class AppButtonStyles {
  static ButtonStyle get attackButton => ElevatedButton.styleFrom(
    backgroundColor: AppTheme.primaryAttack,
    foregroundColor: AppTheme.textWhite,
  );
  
  static ButtonStyle get defendButton => ElevatedButton.styleFrom(
    backgroundColor: AppTheme.primaryDefend,
    foregroundColor: AppTheme.textWhite,
  );
  
  static ButtonStyle get successButton => ElevatedButton.styleFrom(
    backgroundColor: AppTheme.successGreen,
    foregroundColor: AppTheme.textWhite,
  );
  
  static ButtonStyle get warningButton => ElevatedButton.styleFrom(
    backgroundColor: AppTheme.dangerOrange,
    foregroundColor: AppTheme.textWhite,
  );
}

// Custom Text Styles
class AppTextStyles {
  static const TextStyle monoNumbers = TextStyle(
    fontFamily: 'RobotoMono',
    fontWeight: FontWeight.bold,
    color: AppTheme.textWhite,
  );
  
  static const TextStyle territoryName = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.bold,
    fontSize: 18,
    color: AppTheme.textWhite,
  );
  
  static const TextStyle ownerName = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 14,
    color: AppTheme.textGray,
  );
  
  static const TextStyle statusText = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );
}

