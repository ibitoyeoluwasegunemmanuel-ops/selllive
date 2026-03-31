// lib/theme.dart — SellLive Design System
import 'package:flutter/material.dart';

class SellLiveTheme {
  // Brand Colors
  static const primaryOrange = Color(0xFFFF5722);    // SellLive orange
  static const primaryDark = Color(0xFFE64A19);      // Darker orange for pressed states
  static const bgDark = Color(0xFF0D0D0D);           // Main dark background
  static const bgCard = Color(0xFF1A1A1A);           // Card background
  static const bgCardElevated = Color(0xFF252525);   // Elevated card
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFAAAAAA);
  static const textHint = Color(0xFF555555);
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFF9800);
  static const error = Color(0xFFF44336);
  static const liveRed = Color(0xFFFF1744);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgDark,
    colorScheme: const ColorScheme.dark(
      primary: primaryOrange,
      secondary: primaryOrange,
      surface: bgCard,
      error: error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bgDark,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      iconTheme: IconThemeData(color: textPrimary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF111111),
      selectedItemColor: primaryOrange,
      unselectedItemColor: textHint,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bgCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF333333)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF333333)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryOrange, width: 1.5),
      ),
      hintStyle: const TextStyle(color: textHint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardTheme(
      color: bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF2A2A2A), width: 0.5),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
      displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
      titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
      bodyLarge: TextStyle(color: textPrimary, fontSize: 15),
      bodyMedium: TextStyle(color: textSecondary, fontSize: 13),
      labelSmall: TextStyle(color: textHint, fontSize: 11),
    ),
  );

  static ThemeData get light => dark; // TODO: add light theme later
}

// Convenience extension for currency formatting
extension CurrencyFormat on num {
  String get toNaira {
    final naira = this / 100;  // convert kobo to naira
    return '₦${naira.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }
}
