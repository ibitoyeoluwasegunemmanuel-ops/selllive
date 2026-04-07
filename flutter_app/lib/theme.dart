// lib/theme.dart — SellLive design system
import 'package:flutter/material.dart';

class SellLiveTheme {
  // ── Brand Colors ──────────────────────────────────────────
  static const primaryOrange = Color(0xFFFF5722);
  static const liveRed       = Color(0xFFFF1744);
  static const success       = Color(0xFF4CAF50);
  static const warning       = Color(0xFFFF9800);
  static const error         = Color(0xFFF44336);

  // ── Backgrounds ───────────────────────────────────────────
  static const bgDark          = Color(0xFF0D0D0D);
  static const bgCard          = Color(0xFF1A1A1A);
  static const bgCardElevated  = Color(0xFF242424);

  // ── Text ──────────────────────────────────────────────────
  static const textPrimary   = Colors.white;
  static const textSecondary = Color(0xFFAAAAAA);
  static const textHint      = Color(0xFF666666);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: primaryOrange,
      secondary: primaryOrange,
      surface: bgCard,
      background: bgDark,
      error: error,
    ),
    scaffoldBackgroundColor: bgDark,

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: bgDark,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      iconTheme: IconThemeData(color: Colors.white),
    ),

    // Bottom Nav
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Color(0xFF111111),
      indicatorColor: Color(0x26FF5722),
      labelTextStyle: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return const TextStyle(color: primaryOrange, fontSize: 11, fontWeight: FontWeight.w600);
        }
        return const TextStyle(color: Color(0xFF666666), fontSize: 11);
      }),
      iconTheme: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return const IconThemeData(color: primaryOrange, size: 24);
        }
        return const IconThemeData(color: Color(0xFF666666), size: 24);
      }),
    ),

    // Input fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bgCard,
      hintStyle: const TextStyle(color: Color(0xFF555555), fontSize: 14),
      labelStyle: const TextStyle(color: Color(0xFF888888)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2A2A2A))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryOrange, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    // Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
      ),
    ),

    // Text buttons
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primaryOrange),
    ),

    // Dividers
    dividerTheme: const DividerThemeData(color: Color(0xFF1E1E1E), thickness: 1),

    // Cards
    cardTheme: CardTheme(
      color: bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFF2A2A2A))),
    ),

    // Chips
    chipTheme: ChipThemeData(
      backgroundColor: bgCard,
      labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
      side: const BorderSide(color: Color(0xFF2A2A2A)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    // SnackBar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: bgCardElevated,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),

    fontFamily: 'SF Pro Display',
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      bodyLarge: TextStyle(color: Colors.white, fontSize: 15),
      bodyMedium: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14),
      bodySmall: TextStyle(color: Color(0xFF888888), fontSize: 12),
    ),
  );
}
