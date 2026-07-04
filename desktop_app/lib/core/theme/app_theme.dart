import 'package:flutter/material.dart';

final class AppTheme {
  // Brand — indigo palette
  static const Color accent = Color(0xFF4F46E5);
  static const Color accentLight = Color(0xFF6366F1);
  static const Color accentDark = Color(0xFF3730A3);

  // Aliases for clarity when using brand colors directly
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF3730A3);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Accents
  static const Color teal = Color(0xFF14B8A6);

  // Typography
  static const String fontArabic = 'Cairo';

  // ── Light palette ──────────────────────────────────
  static const Color lightBg = Color(0xFFF1F5F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFCBD5E1);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // ── Dark palette ───────────────────────────────────
  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurface2 = Color(0xFF334155);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // ── Sidebar ────────────────────────────────────────
  static const Color sidebarBg = Color(0xFF0F172A);
  static const Color sidebarHover = Color(0xFF1E293B);
  static const Color sidebarActive = Color(0xFF4F46E5);
  static const Color sidebarText = Color(0xFF94A3B8);
  static const Color sidebarTextActive = Color(0xFFFFFFFF);

  // ── Spacing scale ──────────────────────────────────
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double spaceXxl = 32;

  // ── Context-aware helpers ──────────────────────────
  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurface : lightSurface;

  static Color card(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurface : lightSurface;

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBorder : lightBorder;

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextPrimary : lightTextPrimary;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : lightTextSecondary;

  static Color textMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextMuted : lightTextMuted;

  // ── Theme presets ──────────────────────────────────

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
        scrolledUnderElevation: 1,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? darkTextPrimary : lightTextPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? darkSurface : lightSurface,
        elevation: isDark ? 0 : 1,
        shadowColor: isDark ? null : Colors.black.withValues(alpha: 0.04),
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
