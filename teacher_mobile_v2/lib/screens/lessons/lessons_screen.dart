import 'package:flutter/material.dart';
import '../../core/glass_theme.dart';
import '../../core/subscription_guard.dart';

class LessonsScreen extends StatelessWidget {
  const LessonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: Text('الدروس', style: TextStyle(color: GlassTheme.textPrimary(context))),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: GlassTheme.cardBg(context),
                    shape: BoxShape.circle,
                    border: Border.all(color: GlassTheme.cardBorder(context)),
                  ),
                  child: const Icon(Icons.construction, size: 48, color: Color(0xFFF59E0B)),
                ),
                const SizedBox(height: 24),
                Text(
                  'قريباً إن شاء الله',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: GlassTheme.textPrimary(context),
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'هذه الميزة قيد التطوير حالياً. ستتوفر في التحديث القادم.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: GlassTheme.textMuted(context),
                    fontFamily: 'Cairo',
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}
