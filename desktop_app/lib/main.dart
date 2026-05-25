import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme.dart';
import 'core/local_db.dart';
import 'core/sync_service.dart';
import 'core/update_service.dart';
import 'core/local_sync/local_sync_service.dart';
import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'providers/sync_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDB.init();

  await windowManager.ensureInitialized();

  final localSync = LocalSyncService();
  await localSync.start();

  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment(
        'SENTRY_DSN',
        defaultValue: '',
      );
      options.tracesSampleRate = 1.0;
      options.environment = const String.fromEnvironment(
        'FLUTTER_ENV',
        defaultValue: 'development',
      );
      options.release = 'darsak_desktop@${AppConstants.appVersion}';
    },
    appRunner: () => runApp(DarsakApp(localSync: localSync)),
  );
}

class DarsakApp extends StatefulWidget {
  final LocalSyncService localSync;
  const DarsakApp({super.key, required this.localSync});

  @override
  State<DarsakApp> createState() => _DarsakAppState();
}

class _DarsakAppState extends State<DarsakApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  void dispose() {
    widget.localSync.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncService = SyncService(localSync: widget.localSync);
    syncService.init();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DataProvider(syncService)),
        ChangeNotifierProvider(create: (_) => SyncProvider(syncService)),
        ChangeNotifierProvider(create: (_) => UpdateService()),
      ],
      child: MaterialApp(
        title: 'DarsakAI Desktop',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _themeMode,
        home: AppEntryPoint(toggleTheme: toggleTheme, themeMode: _themeMode),
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          );
        },
      ),
    );
  }
}

class AppEntryPoint extends StatefulWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;

  const AppEntryPoint({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
  });

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().loadUser();
      context.read<UpdateService>().checkForUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isAuthenticated) {
          if (auth.onboardingCompleted) {
            return DashboardScreen(toggleTheme: widget.toggleTheme, themeMode: widget.themeMode);
          }
          return OnboardingScreen(toggleTheme: widget.toggleTheme, themeMode: widget.themeMode);
        }
        return LoginScreen(toggleTheme: widget.toggleTheme, themeMode: widget.themeMode);
      },
    );
  }
}
