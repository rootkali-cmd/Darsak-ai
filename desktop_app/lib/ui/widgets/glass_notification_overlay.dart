import 'package:flutter/material.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_theme.dart';

/// Glass notification overlay. Place inside a Stack at bottom-center.
class GlassNotificationOverlay extends StatefulWidget {
  const GlassNotificationOverlay({super.key});

  @override
  State<GlassNotificationOverlay> createState() => _GlassNotificationOverlayState();
}

class _GlassNotificationOverlayState extends State<GlassNotificationOverlay> {
  @override
  void initState() {
    super.initState();
    NotificationService.instance.addListener(_onChange);
  }

  @override
  void dispose() {
    NotificationService.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final notifications = NotificationService.instance.notifications;
    if (notifications.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: notifications.asMap().entries.map((entry) {
            final idx = entry.key;
            final n = entry.value;
            // Older notifications are pushed down and fade
            final opacity = 1.0 - (idx * 0.18);
            final scale = 1.0 - (idx * 0.04);
            return Opacity(
              opacity: opacity.clamp(0.3, 1.0),
              child: Transform.scale(
                scale: scale.clamp(0.85, 1.0),
                child: _GlassCard(notification: n, surfaceColor: surfaceColor, textPrimary: textPrimary, textMuted: textMuted),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final GlassNotification notification;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textMuted;
  const _GlassCard({required this.notification, required this.surfaceColor, required this.textPrimary, required this.textMuted});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: notification.color.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: notification.color.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: notification.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(notification.icon, size: 18, color: notification.color),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  notification.title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (notification.subtitle != null)
                  Text(
                    notification.subtitle!,
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
