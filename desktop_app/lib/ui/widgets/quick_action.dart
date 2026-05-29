import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class QuickAction extends StatefulWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const QuickAction({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  State<QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<QuickAction> {
  bool _isHovered = false;

  Color get _accentColor => widget.color ?? AppTheme.accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 140,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered ? _accentColor.withValues(alpha: 0.3) : borderColor,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: _accentColor.withValues(alpha: 0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_accentColor, _accentColor.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
