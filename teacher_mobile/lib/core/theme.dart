import 'package:flutter/material.dart';

class AppTheme {
  static const Color accent = Color(0xFF2563EB);
  static const Color accentLight = Color(0xFF3B82F6);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color darkBg = Color(0xFF0A0A0A);
  static const Color darkSurface = Color(0xFF141414);
  static const Color darkSurface2 = Color(0xFF1E1E1E);
  static const Color darkBorder = Color(0xFF2A2A2A);
  static const Color darkTextPrimary = Color(0xFFF5F5F5);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkTextMuted = Color(0xFF707070);

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBg,
    // fontFamily: 'Cairo',
    colorScheme: ColorScheme.dark(
      primary: accent,
      secondary: accentLight,
      surface: darkSurface,
      background: darkBg,
      error: danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBg,
      foregroundColor: darkTextPrimary,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(
      color: darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
  );
}
