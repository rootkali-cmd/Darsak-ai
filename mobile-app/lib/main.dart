import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:intl/date_symbol_data_local.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/theme.dart';
import 'core/local_db.dart';
import 'services/analytics_service.dart';
import 'services/structured_logger.dart';
import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'services/update_service.dart';
import 'screens/teacher_connect_screen.dart';
import 'screens/home_screen.dart';
import 'screens/subscription_screen.dart';
import 'widgets/update_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDB.init();
  await AnalyticsService.instance.init();
  await StructuredLogger.instance.init();
  await initializeDateFormatting('ar');
  Intl.defaultLocale = 'ar';
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  AnalyticsService.instance.appOpened();
  StructuredLogger.instance.info('app_started', data: {
    'version': '1.1.0',
    'platform': 'android',
  });

  runApp(const DarsakMobileApp());
}

class DarsakMobileApp extends StatelessWidget {
  const DarsakMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DataProvider()),
        ChangeNotifierProvider(create: (_) => AndroidUpdateService()),
      ],
      child: MaterialApp(
        title: 'DarsakAI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AuthGate(),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        ),
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

    switch (auth.status) {
      case AuthStatus.uninitialized:
        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0A),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF3B82F6)]),
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  child: const Icon(Icons.school, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 24),
                const Text('DarsakAI', style: TextStyle(color: Color(0xFFF5F5F5), fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
        );
      case AuthStatus.authenticated:
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
        return const HomeScreen();
      case AuthStatus.subscriptionExpired:
        return const SubscriptionScreen();
      case AuthStatus.unauthenticated:
      case AuthStatus.loading:
        return const TeacherConnectScreen();
    }
  }
}
