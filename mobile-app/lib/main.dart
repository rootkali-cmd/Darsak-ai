import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:intl/date_symbol_data_local.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/api_service.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'core/local_db.dart';
import 'services/analytics_service.dart';
import 'services/structured_logger.dart';
import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';
import 'screens/login/student_type_screen.dart';
import 'screens/home_screen.dart';
import 'screens/maintenance_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize FCM before runApp (must be awaited for background handler)
  await FcmService.init();

  runApp(const DarsakMobileApp());

  // Initialize remaining services in background
  _initBackground();
}

Future<void> _initBackground() async {
  // Run all initializations in parallel (FCM already initialized in main)
  await Future.wait([
    LocalDB.init(),
    AnalyticsService.instance.init(),
    StructuredLogger.instance.init(),
    initializeDateFormatting('ar'),
    NotificationService().initialize(),
  ]);
  Intl.defaultLocale = 'ar';
  AnalyticsService.instance.appOpened();
  StructuredLogger.instance.info('app_started', data: {
    'version': AppConstants.appVersion,
    'platform': 'android',
  });
}

class DarsakMobileApp extends StatelessWidget {
  const DarsakMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DataProvider()),
      ],
      child: Consumer<ThemeNotifier>(
        builder: (context, themeNotifier, _) {
          return MaterialApp(
            title: 'DarsakAI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeNotifier.themeMode,
            home: const AuthGate(),
            builder: (context, child) => Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checkingMaintenance = true;
  bool _underMaintenance = false;
  String _maintenanceMessage = '';

  @override
  void initState() {
    super.initState();
    FcmService.onMaintenanceRestored = () {
      if (mounted) _checkAppStatus();
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAppStatus();
    });
  }

  Future<void> _checkAppStatus() async {
    try {
      final status = await ApiService().getAppStatus();
      if (!mounted) return;
      final underMaintenance = status['under_maintenance'] == true;
      if (underMaintenance) {
        setState(() {
          _underMaintenance = true;
          _maintenanceMessage = status['maintenance_message']?.toString() ?? 'التطبيق تحت الصيانة حالياً. يرجى المحاولة لاحقاً.';
          _checkingMaintenance = false;
        });
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _checkingMaintenance = false);
    context.read<AuthProvider>().tryAutoLogin();
  }

  @override
  Widget build(BuildContext context) {
    if (_underMaintenance) {
      return MaintenanceScreen(message: _maintenanceMessage);
    }

    final auth = context.watch<AuthProvider>();

    if (auth.status == AuthStatus.authenticated) {
      return const HomeScreen();
    }

    if (auth.status == AuthStatus.uninitialized || _checkingMaintenance) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.accent, AppTheme.accent.withValues(alpha: 0.8)],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school, size: 64, color: Colors.white),
                SizedBox(height: 24),
                Text('دَرسَك AI', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                SizedBox(height: 24),
                CircularProgressIndicator(color: Colors.white),
              ],
            ),
          ),
        ),
      );
    }

    return const StudentTypeScreen();
  }
}
