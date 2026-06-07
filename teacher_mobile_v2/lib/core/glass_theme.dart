import 'package:flutter/material.dart';

class GlassTheme {
  static const Color bgDark = Color(0xFF000000);
  static const Color bgCard = Color(0xFF111111);
  static const Color cyan = Color(0xFF00F3FF);
  static const Color indigo = Color(0xFF6366F1);
  static const Color green = Color(0xFF10B981);
  static const Color red = Color(0xFFEF4444);

  static bool _isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  static Color cardBg(BuildContext context) => _isDark(context)
      ? Colors.white.withValues(alpha: 0.07)
      : Colors.white;
  static Color cardBorder(BuildContext context) => _isDark(context)
      ? Colors.white.withValues(alpha: 0.12)
      : const Color(0xFFE2E8F0);
  static Color textPrimary(BuildContext context) => _isDark(context)
      ? Colors.white
      : const Color(0xFF111111);
  static Color textSecondary(BuildContext context) => _isDark(context)
      ? const Color(0xFF94A3B8)
      : const Color(0xFF64748B);
  static Color textMuted(BuildContext context) => _isDark(context)
      ? Colors.white.withValues(alpha: 0.7)
      : const Color(0xFF94A3B8);
  static Color iconPrimary(BuildContext context) => _isDark(context)
      ? Colors.white
      : const Color(0xFF111111);
  static Color iconSecondary(BuildContext context) => _isDark(context)
      ? Colors.white54
      : Colors.black45;
  static Color chipUnselected(BuildContext context) => _isDark(context)
      ? Colors.white.withValues(alpha: 0.06)
      : const Color(0xFFF1F5F9);

  static BoxDecoration glassCard(BuildContext context) => BoxDecoration(
    color: cardBg(context),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: cardBorder(context)),
    boxShadow: _isDark(context) ? null : [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 12,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration glassCardColored(Color color) => BoxDecoration(
    color: color.withValues(alpha: 0.10),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: color.withValues(alpha: 0.25)),
  );

  static InputDecoration glassInput(BuildContext context, String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: textSecondary(context)),
    prefixIcon: Icon(icon, color: iconSecondary(context)),
    filled: true,
    fillColor: _isDark(context) ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: cardBorder(context)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: cardBorder(context)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: indigo, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  static InputDecoration glassFormInput(BuildContext context, String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: textSecondary(context)),
    prefixIcon: Icon(icon, color: iconSecondary(context)),
    filled: true,
    fillColor: _isDark(context) ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: cardBorder(context)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: cardBorder(context)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: indigo, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  static PreferredSizeWidget glassAppBar(String title, {List<Widget>? actions, PreferredSizeWidget? bottom}) {
    return AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      actions: actions,
      bottom: bottom,
    );
  }

  static Widget glassFAB(VoidCallback onPressed, {IconData icon = Icons.add, Color color = indigo}) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: color,
      elevation: 4,
      child: Icon(icon, color: Colors.white),
    );
  }

  static Widget glassFilterChip(BuildContext context, String label, bool selected, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : chipUnselected(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : cardBorder(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : textSecondary(context),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
