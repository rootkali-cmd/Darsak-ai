import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:darsak_desktop/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('dark theme has correct background color', () {
      expect(AppTheme.darkTheme.scaffoldBackgroundColor, AppTheme.darkBg);
    });

    test('light theme has correct background color', () {
      expect(AppTheme.lightTheme.scaffoldBackgroundColor, AppTheme.lightBg);
    });

    test('dark theme uses dark brightness', () {
      expect(AppTheme.darkTheme.brightness, Brightness.dark);
    });

    test('light theme uses light brightness', () {
      expect(AppTheme.lightTheme.brightness, Brightness.light);
    });

    test('both themes use Material 3', () {
      expect(AppTheme.darkTheme.useMaterial3, true);
      expect(AppTheme.lightTheme.useMaterial3, true);
    });

    test('accent color constants are defined', () {
      expect(AppTheme.accent, const Color(0xFF2563EB));
      expect(AppTheme.success, const Color(0xFF10B981));
      expect(AppTheme.warning, const Color(0xFFF59E0B));
      expect(AppTheme.danger, const Color(0xFFEF4444));
    });

    test('dark theme elevated button has accent background', () {
      final buttonStyle = AppTheme.darkTheme.elevatedButtonTheme.style;
      expect(buttonStyle, isNotNull);
    });

    test('dark theme input decoration has correct fill color', () {
      final inputTheme = AppTheme.darkTheme.inputDecorationTheme;
      expect(inputTheme.fillColor, AppTheme.darkSurface2);
      expect(inputTheme.filled, true);
    });

    test('light theme input decoration has correct fill color', () {
      final inputTheme = AppTheme.lightTheme.inputDecorationTheme;
      expect(inputTheme.fillColor, AppTheme.lightSurface2);
    });
  });
}
