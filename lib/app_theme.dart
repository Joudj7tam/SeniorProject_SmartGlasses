import 'package:flutter/material.dart';

// Global theme mode notifier — updated by the mode toggle in HomePage.
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.light);

// ── Dark palette ────────────────────────────────────────────────────────────
// Page / scaffold backgrounds
const Color kDarkBg1 = Color(0xFF0B1929); // deep navy — top of gradient
const Color kDarkBg2 = Color(0xFF112236); // mid-gradient
const Color kDarkBg3 = Color(0xFF0F2744); // bottom of gradient

// Cards
const Color kDarkCard     = Color(0xFF132236); // primary card surface
const Color kDarkCardElev = Color(0xFF1B3147); // elevated / inner card
const Color kDarkBorder   = Color(0xFF1E3D5A); // card & input borders

// Typography
const Color kDarkText  = Color(0xFFEBF5FB); // primary text
const Color kDarkMuted = Color(0xFF7EB5C8); // secondary / hint text

// Accent — intentionally kept identical to light mode for brand consistency
const Color kDarkAccent     = Color(0xFF2EC4B6); // teal
const Color kDarkAccentSoft = Color(0xFF0D2A38); // teal ghost background
const Color kDarkOrange     = Color(0xFFFF9F1C); // orange
const Color kDarkOrangeSoft = Color(0xFF2A1F0E); // orange ghost background
const Color kDarkBlue       = Color(0xFF4A9ECA); // blue accent
const Color kDarkBlueSoft   = Color(0xFF0D1D2E); // blue ghost background

// ── Dark ThemeData ──────────────────────────────────────────────────────────
ThemeData buildDarkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kDarkBg1,
    colorScheme: const ColorScheme.dark(
      primary: kDarkAccent,
      secondary: kDarkBlue,
      surface: kDarkCard,
      onSurface: kDarkText,
      outline: kDarkBorder,
    ),
    cardColor: kDarkCard,
    bottomAppBarTheme: const BottomAppBarThemeData(color: Color(0xFF0F2035)),
    dividerColor: kDarkBorder,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kDarkCard,
      labelStyle: const TextStyle(color: kDarkMuted),
      hintStyle: const TextStyle(color: kDarkMuted),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: kDarkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: kDarkAccent, width: 1.4),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? kDarkAccent : kDarkMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? kDarkAccentSoft
            : kDarkBorder,
      ),
    ),
    useMaterial3: true,
  );
}
