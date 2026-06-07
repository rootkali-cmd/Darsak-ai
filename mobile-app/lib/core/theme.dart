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
      scaffoldBackgroundColor: Colors.black,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: Colors.white,
        secondary: accentLight,
        error: danger,
        surface: Color(0xFF0A0A0A),
        onSurface: Color(0xFFF5F5F5),
      ),
      cardColor: const Color(0xFF0A0A0A),
      dividerColor: const Color(0xFF1A1A1A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
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

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: accent,
        onPrimary: Colors.white,
        secondary: accentLight,
        error: danger,
        surface: Color(0xFFF8F9FA),
        onSurface: Color(0xFF111827),
      ),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFE5E7EB),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Color(0xFF111827),
      ),
      textTheme: GoogleFonts.cairoTextTheme(
        const TextTheme(
          headlineLarge: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(color: Color(0xFF111827)),
          bodyMedium: TextStyle(color: Color(0xFF6B7280)),
        ),
      ),
    );
  }
}

class AppColors {
  static Color background(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black
        : Colors.white;
  }

  static Color surface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0A0A0A)
        : const Color(0xFFF8F9FA);
  }

  static Color surfaceElevated(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF141414)
        : Colors.white;
  }

  static Color surfaceHigher(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF0F0F0);
  }

  static Color border(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFE5E7EB);
  }

  static Color textPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF5F5F5)
        : const Color(0xFF111827);
  }

  static Color textSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);
  }

  static Color dialogBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF141414)
        : Colors.white;
  }

  static Color inputFill(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0A0A0A)
        : const Color(0xFFF3F4F6);
  }

  static LinearGradient headerGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const LinearGradient(colors: [Color(0xFF1E3A5F), Colors.black])
        : const LinearGradient(colors: [Color(0xFFDBEAFE), Colors.white]);
  }

  static LinearGradient cardGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const LinearGradient(colors: [Color(0xFF1E1E1E), Color(0xFF141414)])
        : const LinearGradient(colors: [Color(0xFFF9FAFB), Colors.white]);
  }

  static Color shimmerBase(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFE5E7EB);
  }

  static Color shimmerHighlight(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFF3F4F6);
  }

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
}
