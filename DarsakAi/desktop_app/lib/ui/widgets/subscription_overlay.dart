import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SubscriptionOverlay extends StatelessWidget {
  final bool isExpired;
  final int daysRemaining;
  final VoidCallback onManage;

  const SubscriptionOverlay({
    super.key,
    required this.isExpired,
    required this.daysRemaining,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    final Color bannerColor = isExpired ? AppTheme.danger : AppTheme.warning;
    final String message = isExpired
        ? 'انتهت صلاحية الاشتراك'
        : 'سينتهي الاشتراك خلال $daysRemaining أيام';

    return Material(
      color: Colors.transparent,
      child: Dismissible(
        key: const ValueKey('subscription_banner'),
        direction: DismissDirection.up,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: bannerColor.withValues(alpha: 0.12),
            border: Border(
              bottom: BorderSide(color: bannerColor.withValues(alpha: 0.3)),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isExpired ? Icons.error_outline : Icons.warning_amber_rounded,
                color: bannerColor,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isExpired ? 'اشتراك منتهي' : 'اشتراك وشيك الانتهاء',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 34,
                child: OutlinedButton(
                  onPressed: onManage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: bannerColor,
                    side: BorderSide(color: bannerColor),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('إدارة الاشتراك'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
