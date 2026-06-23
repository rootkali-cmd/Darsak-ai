import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../ui/screens/subscription/subscription_screen.dart';
import '../theme/app_theme.dart';

/// Check if the teacher has an active subscription.
/// Returns true if active, false if dialog was shown.
/// Now waits for subscription to load if not yet loaded.
Future<bool> checkSubscription(BuildContext context) async {
  final auth = context.read<AuthProvider>();

  // If subscription data not loaded yet, wait for it
  if (auth.subscriptionData == null && !auth.subscriptionLoaded) {
    await auth.refreshSubscription();
  }

  if (auth.hasSubscription) return true;
  if (context.mounted) {
    _showSubscriptionRequiredDialog(context);
  }
  return false;
}

void _showSubscriptionRequiredDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: const Icon(Icons.lock_outline, color: Colors.orange, size: 48),
      title: const Text('اشتراك مطلوب', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
      content: const Text(
        'يجب الاشتراك في باقة أولاً لاستخدام هذه الميزة',
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('إغلاق', style: TextStyle(color: Colors.grey)),
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('الذهاب للاشتراكات', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ),
  );
}
