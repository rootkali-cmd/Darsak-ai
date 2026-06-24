import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/subscriptions/subscription_screen.dart';
import 'app_theme.dart';
import 'glass_theme.dart';

/// Feature names that map to plan features
class PlanFeatures {
  static const exams = 'exams';
  static const aiGenerateExam = 'ai_generate_exam';
  static const students = 'students';
  static const attendance = 'attendance';
  static const grades = 'grades';
  static const groups = 'groups';
  static const lessons = 'lessons';
  static const invoices = 'invoices';
  static const aiReports = 'ai_reports';

  static String featureName(String feature) {
    switch (feature) {
      case exams: return 'الاختبارات';
      case aiGenerateExam: return 'تحضير اختبارات بالـ AI';
      case students: return 'إدارة الطلاب';
      case attendance: return 'الحضور والغياب';
      case grades: return 'الدرجات';
      case groups: return 'المجموعات';
      case lessons: return 'الدروس المشتركة';
      case invoices: return 'الفواتير';
      case aiReports: return 'تقارير AI';
      default: return feature;
    }
  }
}

/// Check if the current plan includes a specific feature.
/// Returns true if allowed, false if not (and shows dialog).
bool checkPlanFeature(BuildContext context, String feature) {
  final auth = context.read<AuthProvider>();
  if (!auth.hasSubscription) {
    showSubscriptionRequiredDialog(context);
    return false;
  }
  final sub = auth.subscription;
  if (sub == null) {
    showSubscriptionRequiredDialog(context);
    return false;
  }
  final planName = (sub['plan_name'] ?? '').toString().toLowerCase();
  final features = sub['plan']?['features'] ?? sub['features'];

  // Check features list if available
  if (features is List) {
    final featureList = features.map((f) => f.toString().toLowerCase()).toList();
    // Map feature key to Arabic feature text that would be in the list
    final arabicFeatures = _featureToArabicList(feature);
    final hasFeature = arabicFeatures.any((af) => featureList.any((f) => f.contains(af)));
    if (hasFeature) return true;
  }

  // Check plan name based rules
  return _checkPlanFeatureByName(planName, feature);
}

bool _checkPlanFeatureByName(String planName, String feature) {
  // Premium has everything
  if (planName.contains('premium') || planName.contains('متكامل')) return true;

  // Pro has most things
  if (planName.contains('pro') || planName.contains('احتراف')) {
    switch (feature) {
      case PlanFeatures.exams:
      case PlanFeatures.aiGenerateExam:
      case PlanFeatures.students:
      case PlanFeatures.attendance:
      case PlanFeatures.grades:
      case PlanFeatures.groups:
      case PlanFeatures.lessons:
      case PlanFeatures.aiReports:
        return true;
      default:
        return false;
    }
  }

  // Basic has limited features
  if (planName.contains('basic') || planName.contains('أساسي')) {
    switch (feature) {
      case PlanFeatures.students:
      case PlanFeatures.attendance:
      case PlanFeatures.grades:
      case PlanFeatures.exams:
        return true;
      default:
        return false;
    }
  }

  return false;
}

List<String> _featureToArabicList(String feature) {
  switch (feature) {
    case PlanFeatures.exams: return ['اختبار', 'اختبارات'];
    case PlanFeatures.aiGenerateExam: return ['تحضير اختبارات', 'ai'];
    case PlanFeatures.students: return ['طالب', 'طلاب', 'student'];
    case PlanFeatures.attendance: return ['حضور', 'غياب'];
    case PlanFeatures.grades: return ['درجات'];
    case PlanFeatures.groups: return ['مجموعات', 'مجموعة'];
    case PlanFeatures.lessons: return ['دروس', 'درس', 'مشترك'];
    case PlanFeatures.invoices: return ['فواتير', 'فاتورة'];
    case PlanFeatures.aiReports: return ['تقارير', 'تقرير', 'ai'];
    default: return [feature];
  }
}

/// Shows a dialog telling the user which plan they need for a feature.
void showFeatureRequiredDialog(BuildContext context, String feature) {
  final featureLabel = PlanFeatures.featureName(feature);
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Icon(Icons.lock_outline, color: AppTheme.accent, size: 48),
      title: Text('ميزة غير متاحة', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ميزة "$featureLabel" غير متاحة في باقتك الحالية',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            'ترقية باقتك للحصول على هذه الميزة',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary(context)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('لاحقاً'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white),
          child: const Text('اشتراك الآن', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

class SubscriptionGuard extends NavigatorObserver {
  static const List<String> _subscriptionRequiredRoutes = [
    '/ai-generate-exam',
    '/add-edit-grade',
    '/students',
    '/groups',
    '/grades',
    '/attendance',
    '/invoices',
    '/lessons',
    '/exams',
  ];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _checkSubscription(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _checkSubscription(newRoute);
  }

  void _checkSubscription(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null) return;

    final requiresSubscription = _subscriptionRequiredRoutes.any(
      (required) => name.startsWith(required),
    );

    if (!requiresSubscription) return;

    final navigator = route.navigator;
    if (navigator == null) return;

    final context = navigator.context;
    final auth = context.read<AuthProvider>();

    if (!auth.hasSubscription) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!navigator.mounted) return;
        Navigator.of(navigator.context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        );
      });
    }
  }
}

/// Call this before any action that requires subscription.
/// Returns true if the user has subscription, false if dialog was shown.
bool checkSubscription(BuildContext context) {
  final auth = context.read<AuthProvider>();
  if (auth.hasSubscription) return true;
  showSubscriptionRequiredDialog(context);
  return false;
}

/// Shows non-dismissible subscription required dialog.
/// No cancel button, no back button dismiss, no barrier dismiss.
void showSubscriptionRequiredDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(ctx).pop();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        );
      },
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.lock_outline, color: Colors.orange, size: 48),
        title: const Text('اشتراك مطلوب', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'يجب الاشتراك في باقة أولاً لاستخدام هذه الميزة',
          textAlign: TextAlign.center,
        ),
        actions: [
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
    ),
  );
}

class SubscriptionRequiredWidget extends StatelessWidget {
  final Widget child;
  final String? message;
  static bool _isRedirecting = false;

  const SubscriptionRequiredWidget({
    super.key,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.hasSubscription && !_isRedirecting) {
          _isRedirecting = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final currentRoute = ModalRoute.of(context)?.settings.name;
            // Only redirect if not already on subscription screen
            if (currentRoute != '/subscription') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            }
            _isRedirecting = false;
          });
          return const SizedBox.shrink();
        }
        return child;
      },
    );
  }
}

extension SubscriptionContext on BuildContext {
  bool get hasActiveSubscription {
    final auth = read<AuthProvider>();
    return auth.hasSubscription;
  }

  void requireSubscription({String? message}) {
    final auth = read<AuthProvider>();
    if (!auth.hasSubscription) {
      Navigator.pushReplacement(
        this,
        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
      );
    }
  }
}
