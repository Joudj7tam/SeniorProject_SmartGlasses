import 'package:flutter/material.dart';

/// Centralized color tokens for the Smart Glasses app.
/// Use these constants everywhere instead of hardcoding hex values.
class AppColors {
  AppColors._();

  // ── Brand accents (shared across both modes) ──
  static const teal = Color(0xFF2EC4B6);
  static const orange = Color(0xFFFF9F1C);
  static const tealLight = Color(0xFFCBF3F0);
  static const danger = Color(0xFFE63946);

  // ── Dark mode tokens ──
  static const darkScaffold = Color(0xFF0D1B2A);
  static const darkSurface = Color(0xFF1B2A3B);
  static const darkSurfaceElevated = Color(0xFF243447);
  static const darkOnSurface = Colors.white;

  // ── Light mode tokens ──
  static const lightScaffold = Color(0xFFFFF7EE);
  static const lightSurface = Colors.white;
  static const lightSurfaceElevated = Color(0xFFFAFAFA);
  static const lightOnSurface = Color(0xFF1A1A1A);
}

/// Provides [AppTheme.light] and [AppTheme.dark] ThemeData objects.
/// Import this in main.dart and pass to MaterialApp.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    const primary = AppColors.orange;
    const secondary = AppColors.teal;
    const onSurface = AppColors.lightOnSurface;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: onSurface,
      surfaceContainerHighest: AppColors.lightSurfaceElevated,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lightScaffold,

      cardColor: AppColors.lightSurface,
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),

      bottomAppBarTheme: const BottomAppBarThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE4DDD4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE4DDD4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: secondary, width: 1.4),
        ),
      ),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: onSurface),
        bodyMedium: TextStyle(color: onSurface),
        bodySmall: TextStyle(color: onSurface),
        titleLarge: TextStyle(color: onSurface),
        titleMedium: TextStyle(color: onSurface),
        titleSmall: TextStyle(color: onSurface),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFFE4DDD4),
        thickness: 1,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return null;
        }),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: secondary,
          side: const BorderSide(color: AppColors.tealLight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  static ThemeData get dark {
    const primary = AppColors.teal;
    const secondary = AppColors.orange;
    const onSurface = AppColors.darkOnSurface;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      surface: AppColors.darkSurface,
      onSurface: onSurface,
      surfaceContainerHighest: AppColors.darkSurfaceElevated,
      // scaffold background handled separately
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkScaffold,

      cardColor: AppColors.darkSurface,
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),

      bottomAppBarTheme: const BottomAppBarThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.teal.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.teal.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
        labelStyle: TextStyle(color: onSurface.withValues(alpha: 0.65)),
        hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.38)),
      ),

      textTheme: TextTheme(
        bodyLarge: const TextStyle(color: onSurface),
        bodyMedium: const TextStyle(color: onSurface),
        bodySmall: TextStyle(color: onSurface.withValues(alpha: 0.65)),
        titleLarge: const TextStyle(color: onSurface),
        titleMedium: const TextStyle(color: onSurface),
        titleSmall: TextStyle(color: onSurface.withValues(alpha: 0.65)),
      ),

      dividerTheme: DividerThemeData(
        color: AppColors.teal.withValues(alpha: 0.15),
        thickness: 1,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return null;
        }),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
