import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'core/subscription_guard.dart';
import 'providers/auth_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';

import 'services/notification_service.dart' as notif;
import 'services/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize FCM before runApp (must be top-level, awaited)
  await FcmService.init();
  notif.NotificationService().initialize();

  runApp(const DarsakApp());
}

class DarsakApp extends StatelessWidget {
  const DarsakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'درسك AI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.mode,
            home: const SplashScreen(),
            navigatorObservers: [SubscriptionGuard()],
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
