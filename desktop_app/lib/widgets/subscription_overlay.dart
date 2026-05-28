import 'dart:ui';
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
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            color: Colors.black.withValues(alpha: 0.4),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Card(
                  margin: EdgeInsets.zero,
                  elevation: 8,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.all(36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(Icons.workspace_premium_outlined, size: 38, color: AppTheme.accent),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'انتهت الفترة التجريبية',
                          style: TextStyle(
                            color: AppTheme.darkTextPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'اشترك في إحدى الباقات لاستعادة جميع المميزات',
                          style: TextStyle(
                            color: AppTheme.darkTextSecondary,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: OutlinedButton.icon(
                                onPressed: onActivate,
                                icon: const Icon(Icons.vpn_key, size: 18),
                                label: const Text('اشتراك في باقة'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.accentLight,
                                  side: const BorderSide(color: AppTheme.accentLight),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
        ),
      ),
    );
  }
}
