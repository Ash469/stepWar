import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const Color primary = Color(0xFFFF6B35);
  static const Color primaryVariant = Color(0xFFE55A2B);
  static const Color secondary = Color(0xFF4ECDC4);
  static const Color secondaryVariant = Color(0xFF44B7AD);
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color card = Color(0xFF2A2A2A);
  static const Color onPrimary = Colors.white;
  static const Color onSecondary = Colors.black;
  static const Color onBackground = Colors.white70;
  static const Color onSurface = Colors.white;
  static const Color onCard = Colors.white;
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF2196F3);
  static const Color stepInactive = Color(0xFF444444);
  static const Color stepActive = primary;
  static const Color stepCompleted = secondary;
}

class AppTextStyles {
  static TextStyle headline1 = GoogleFonts.montserrat(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  static TextStyle headline2 = GoogleFonts.montserrat(
    fontSize: 28,
    fontWeight: FontWeight.bold,
  );

  static TextStyle titleLarge = GoogleFonts.montserrat(
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static TextStyle titleMedium = GoogleFonts.montserrat(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static TextStyle bodyLarge = GoogleFonts.montserrat(
    fontSize: 16,
    height: 1.5,
  );

  static TextStyle bodyMedium = GoogleFonts.montserrat(
    fontSize: 14,
    height: 1.4,
  );

  static TextStyle labelLarge = GoogleFonts.montserrat(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static TextStyle caption = GoogleFonts.montserrat(
    fontSize: 12,
    color: AppColors.onBackground,
  );
}

class AppThemes {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background, // This is your app bar color
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: AppTextStyles.titleLarge,

      // ADD THIS for global status bar styling
      systemOverlayStyle: const SystemUiOverlayStyle(
        // Make the status bar color match the AppBar color
        statusBarColor: AppColors.background, 
        // For a dark background, you need light icons
        statusBarIconBrightness: Brightness.light, 
      ),
    ),
    textTheme: TextTheme(
      displayLarge: AppTextStyles.headline1,
      displayMedium: AppTextStyles.headline2,
      titleLarge: AppTextStyles.titleLarge,
      titleMedium: AppTextStyles.titleMedium,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.bodyMedium,
      labelLarge: AppTextStyles.labelLarge,
      labelSmall: AppTextStyles.caption,
    ),
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      background: Colors.white,
      surface: Colors.grey[50]!,
      onPrimary: AppColors.onPrimary,
      onSecondary: AppColors.onSecondary,
      onBackground: Colors.black87,
      onSurface: Colors.black,
      error: AppColors.error,
    ),
    cardTheme: CardThemeData(
      color: Colors.grey[100],
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: AppTextStyles.labelLarge,
      ),
    ),
    fontFamily: GoogleFonts.montserrat().fontFamily,
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: AppTextStyles.titleLarge,
      // Ensure proper status bar handling for dark theme
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.surface, // Navigation bar color
        systemNavigationBarIconBrightness: Brightness.light, // Navigation bar icons
      ),
    ),
    textTheme: TextTheme(
      displayLarge: AppTextStyles.headline1.copyWith(color: Colors.white),
      displayMedium: AppTextStyles.headline2.copyWith(color: Colors.white),
      titleLarge: AppTextStyles.titleLarge.copyWith(color: Colors.white),
      titleMedium: AppTextStyles.titleMedium.copyWith(color: Colors.white),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(color: AppColors.onBackground),
      bodyMedium: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground),
      labelLarge: AppTextStyles.labelLarge.copyWith(color: Colors.white),
      labelSmall: AppTextStyles.caption,
    ),
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      background: AppColors.background,
      surface: AppColors.surface,
      onPrimary: AppColors.onPrimary,
      onSecondary: AppColors.onSecondary,
      onBackground: AppColors.onBackground,
      onSurface: AppColors.onSurface,
      error: AppColors.error,
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: AppTextStyles.labelLarge,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Colors.white54,
      elevation: 0,
    ),
    fontFamily: GoogleFonts.montserrat().fontFamily,
  );
}