import 'package:flutter/material.dart';

class GlassTheme {
  static const Color bgDark = Color(0xFF000000);
  static const Color bgCard = Color(0xFF111111);
  static const Color cyan = Color(0xFF00F3FF);
  static const Color indigo = Color(0xFF6366F1);
  static const Color green = Color(0xFF10B981);
  static const Color red = Color(0xFFEF4444);

  static BoxDecoration get glassCard => BoxDecoration(
    color: Colors.white.withValues(alpha: 0.07),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
  );

  static BoxDecoration glassCardLight(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return glassCard;
    }
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static BoxDecoration glassCardColored(Color color) => BoxDecoration(
    color: color.withValues(alpha: 0.10),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: color.withValues(alpha: 0.25)),
  );

  static InputDecoration glassInput(String hint, IconData icon, {bool isDark = true}) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
    prefixIcon: Icon(icon, color: isDark ? Colors.white54 : Colors.black45),
    filled: true,
    fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE2E8F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE2E8F0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: indigo, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  static InputDecoration glassFormInput(String label, IconData icon, {bool isDark = true}) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
    prefixIcon: Icon(icon, color: isDark ? Colors.white54 : Colors.black45),
    filled: true,
    fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE2E8F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE2E8F0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: indigo, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  static PreferredSizeWidget glassAppBar(String title, {List<Widget>? actions, PreferredSizeWidget? bottom}) {
    return AppBar(
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  static Widget glassFilterChip(String label, bool selected, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF94A3B8),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
