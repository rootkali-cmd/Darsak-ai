import 'package:flutter/material.dart';
import '../core/theme.dart';

class SubscriptionOverlay extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback onActivate;

  const SubscriptionOverlay({
    super.key,
    required this.onRefresh,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Card(
              margin: EdgeInsets.zero,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.error_outline, size: 44, color: AppTheme.warning),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'تم تعليق جميع الخدمات',
                      style: TextStyle(
                        color: AppTheme.darkTextPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'الرجاء تجديد الاشتراك',
                      style: TextStyle(
                        color: AppTheme.darkTextSecondary,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: ElevatedButton.icon(
                            onPressed: onRefresh,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('تحديث'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: OutlinedButton.icon(
                            onPressed: onActivate,
                            icon: const Icon(Icons.vpn_key, size: 18),
                            label: const Text('تفعيل كود'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.accentLight,
                              side: const BorderSide(color: AppTheme.accentLight),
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
