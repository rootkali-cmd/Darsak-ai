import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color accent = Color(0xFF2563EB);
  static const Color accentLight = Color(0xFF3B82F6);
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: Colors.white,
        secondary: accentLight,
        error: danger,
        surface: Color(0xFF141414),
        onSurface: Color(0xFFF5F5F5),
      ),
      cardColor: const Color(0xFF141414),
      dividerColor: const Color(0xFF2A2A2A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A0A0A),
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: GoogleFonts.cairoTextTheme(
        const TextTheme(
          headlineLarge: TextStyle(color: Color(0xFFF5F5F5), fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(color: Color(0xFFF5F5F5)),
          bodyMedium: TextStyle(color: Color(0xFF9CA3AF)),
        ),
      ),
    );
  }
}
