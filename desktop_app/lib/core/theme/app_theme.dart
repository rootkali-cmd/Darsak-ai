import 'package:flutter/material.dart';

final class AppTheme {
  static const Color accent = Color(0xFF2563EB);
  static const Color accentLight = Color(0xFF3B82F6);
  static const Color accentDark = Color(0xFF1D4ED8);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const String fontArabic = 'Cairo';

  static const Color darkBg = Color(0xFF0A0A0A);
  static const Color darkSurface = Color(0xFF141414);
  static const Color darkSurface2 = Color(0xFF1E1E1E);
  static const Color darkBorder = Color(0xFF2A2A2A);
  static const Color darkTextPrimary = Color(0xFFF5F5F5);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkTextMuted = Color(0xFF707070);

  static const Color lightBg = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF0F2F5);
  static const Color lightBorder = Color(0xFFE2E5EA);
  static const Color lightTextPrimary = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF555570);
  static const Color lightTextMuted = Color(0xFF8888A0);

  static const Color bg = darkBg;
  static const Color bgSecondary = darkSurface;
  static const Color cardBg = darkSurface;
  static const Color textPrimary = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;
  static const Color textMuted = darkTextMuted;
  static const Color border = darkBorder;
  static const Color accent2 = accentLight;
  static const Color accent3 = success;

  static TextStyle hudText = const TextStyle(
    fontFamily: fontArabic,
    fontSize: 11,
    color: darkTextMuted,
  );

  static ThemeData _baseTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final ColorScheme colorScheme;
    if (isDark) {
      colorScheme = const ColorScheme.dark(
        primary: accent,
        secondary: accentLight,
        surface: darkSurface,
        surfaceContainerHighest: darkSurface2,
        error: danger,
      );
    } else {
      colorScheme = const ColorScheme.light(
        primary: accent,
        secondary: accentLight,
        surface: lightSurface,
        surfaceContainerHighest: lightSurface2,
        error: danger,
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? darkBg : lightBg,
      primaryColor: accent,
      fontFamily: fontArabic,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? darkSurface : lightSurface,
        foregroundColor: isDark ? darkTextPrimary : lightTextPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? darkTextPrimary : lightTextPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? darkSurface : lightSurface,
        elevation: isDark ? 0 : 2,
        shadowColor: isDark ? null : Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isDark ? darkBorder : lightBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkSurface2 : lightSurface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? darkBorder : lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? darkBorder : lightBorder),
        ),
        labelStyle: TextStyle(
          color: isDark ? darkTextSecondary : lightTextSecondary,
          fontSize: 13,
        ),
        hintStyle: TextStyle(
          color: isDark ? darkTextMuted : lightTextMuted,
          fontSize: 13,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentLight,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? darkBorder : lightBorder,
        thickness: 1,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: isDark ? darkTextPrimary : lightTextPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 28,
        ),
        headlineMedium: TextStyle(
          color: isDark ? darkTextPrimary : lightTextPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
        titleLarge: TextStyle(
          color: isDark ? darkTextPrimary : lightTextPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
        titleMedium: TextStyle(
          color: isDark ? darkTextPrimary : lightTextPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        bodyLarge: TextStyle(
          color: isDark ? darkTextPrimary : lightTextPrimary,
          fontSize: 15,
        ),
        bodyMedium: TextStyle(
          color: isDark ? darkTextSecondary : lightTextSecondary,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: isDark ? darkTextMuted : lightTextMuted,
          fontSize: 12,
        ),
      ),
    );
  }

  static ThemeData get darkTheme => _baseTheme(Brightness.dark);
  static ThemeData get lightTheme => _baseTheme(Brightness.light);
}
