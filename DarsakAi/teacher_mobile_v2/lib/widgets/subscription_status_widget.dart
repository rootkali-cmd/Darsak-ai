import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/glass_theme.dart';
import '../providers/auth_provider.dart';
import '../screens/subscription/subscription_plans_screen.dart';

class SubscriptionStatusWidget extends StatefulWidget {
  const SubscriptionStatusWidget({super.key});

  @override
  State<SubscriptionStatusWidget> createState() => _SubscriptionStatusWidgetState();
}

class _SubscriptionStatusWidgetState extends State<SubscriptionStatusWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final sub = auth.subscription;
        final isActive = sub != null && sub['is_active'] == true && sub['is_expired'] != true;
        final daysLeft = sub?['days_remaining'] ?? 0;
        final planName = sub?['plan_name']?.toString() ?? '';
        final examsUsed = sub?['exams_used'] ?? 0;
        final examsLimit = sub?['exams_limit'] ?? 0;

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionPlansScreen())),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: isActive
                  ? LinearGradient(
                      colors: [AppTheme.accent.withValues(alpha: 0.12), AppTheme.accent.withValues(alpha: 0.06)],
                    )
                  : LinearGradient(
                      colors: [AppTheme.warning.withValues(alpha: 0.12), AppTheme.warning.withValues(alpha: 0.06)],
                    ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? AppTheme.accent.withValues(alpha: 0.25)
                    : AppTheme.warning.withValues(alpha: 0.25),
              ),
            ),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isActive
                        ? [AppTheme.accent, AppTheme.accent.withValues(alpha: 0.7)]
                        : [AppTheme.warning, AppTheme.warning.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isActive ? Icons.card_membership_rounded : Icons.card_giftcard_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isActive && planName.isNotEmpty ? planName : 'اشترك الآن',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: GlassTheme.textPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isActive) ...[
                      const SizedBox(height: 1),
                      Row(children: [
                        if (examsLimit > 0) ...[
                          Text('اختبارات: $examsUsed/$examsLimit', style: TextStyle(fontSize: 10, color: GlassTheme.textSecondary(context))),
                          const SizedBox(width: 8),
                        ],
                        Text('$daysLeft يوم', style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: daysLeft < 3 ? AppTheme.danger : AppTheme.success,
                        )),
                      ]),
                    ] else ...[
                      const SizedBox(height: 1),
                      Text('اضغط للاشتراك', style: TextStyle(fontSize: 10, color: GlassTheme.textSecondary(context))),
                    ],
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: GlassTheme.textSecondary(context)),
            ]),
          ),
        );
      },
    );
  }
}
