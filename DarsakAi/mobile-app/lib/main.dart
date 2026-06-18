import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:intl/date_symbol_data_local.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'core/local_db.dart';
import 'services/analytics_service.dart';
import 'services/structured_logger.dart';
import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'providers/theme_provider.dart';
import 'services/update_service.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';
import 'screens/teacher_connect_screen.dart';
import 'screens/home_screen.dart';
import 'widgets/update_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize Firebase first
  await Firebase.initializeApp();

  runApp(const DarsakMobileApp());

  // Initialize services in background AFTER app is shown
  _initBackground();
}

Future<void> _initBackground() async {
  // Run all initializations in parallel
  await Future.wait([
    LocalDB.init(),
    AnalyticsService.instance.init(),
    StructuredLogger.instance.init(),
    initializeDateFormatting('ar'),
    NotificationService().initialize(),
    PushNotificationService().initialize(),
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
        ChangeNotifierProvider(create: (_) => AndroidUpdateService()),
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().tryAutoLogin();
    });
  }

  void _checkUpdate() {
    final update = context.read<AndroidUpdateService>();
    update.checkForUpdate().then((_) {
      if (!mounted || !update.hasUpdate || update.updateInfo == null) return;
      AndroidUpdateDialog.show(context, update.updateInfo!).then((shouldOpen) {
        if (shouldOpen == true && update.updateInfo?.downloadUrl != null) {
          final uri = Uri.parse(update.updateInfo!.downloadUrl!);
          canLaunchUrl(uri).then((can) {
            if (can) launchUrl(uri, mode: LaunchMode.externalApplication);
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.status == AuthStatus.authenticated) {
      return const HomeScreen();
    }

    // Show TeacherConnect immediately for all other states
    // (uninitialized, unauthenticated, loading)
    return const TeacherConnectScreen();
  }
}
