import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/constants.dart';
import 'core/utils/logger.dart';
import 'core/database/database_service.dart';
import 'core/api/api_client.dart';
import 'core/api/api_service.dart';
import 'core/sync/sync_service.dart';
import 'core/sync/sync_queue_manager.dart';
import 'core/services/analytics_service.dart';
import 'core/services/remote_config_service.dart';
import 'core/local_sync/local_sync_service.dart';
import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'providers/sync_provider.dart';
import 'ui/screens/login/login_screen.dart';
import 'ui/screens/dashboard/dashboard_screen.dart';
import 'ui/screens/onboarding/onboarding_screen.dart';

late String _dbPath;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  await AppLogger.instance.init();
  await AnalyticsService.instance.init();
  await RemoteConfigService.instance.init();

  final appDir = await getApplicationSupportDirectory();
  _dbPath = '${appDir.path}/darsak_db/darsak.db';
  await DatabaseService.instance.init(_dbPath);

  final localSync = LocalSyncService();
  await localSync.start();

  AppLogger.instance.info('app_started', data: {
    'version': AppConstants.appVersion,
    'platform': AppConstants.platformName,
  });
  AnalyticsService.instance.appOpened();

  runApp(DarsakApp(localSync: localSync));
}

class DarsakApp extends StatefulWidget {
  final LocalSyncService localSync;
  const DarsakApp({super.key, required this.localSync});

  @override
  State<DarsakApp> createState() => _DarsakAppState();
}

class _DarsakAppState extends State<DarsakApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  late final ApiClient _apiClient;
  late final ApiService _apiService;
  late final SyncQueueManager _syncQueue;
  late final SyncService _syncService;
  late final AuthProvider _authProvider;
  late final DataProvider _dataProvider;
  late final SyncProvider _syncProvider;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _apiService = ApiService(_apiClient);
    _authProvider = AuthProvider(_apiClient);
    _apiClient.onUnauthorized = () {
      _authProvider.logout();
    };
    _syncQueue = SyncQueueManager(DatabaseService.instance);
    _syncService = SyncService(
      api: _apiService,
      queue: _syncQueue,
      db: DatabaseService.instance,
      dbPath: _dbPath,
    );
    _syncService.init();
    _dataProvider = DataProvider(
      api: _apiService,
      sync: _syncService,
      db: DatabaseService.instance,
    );
    _syncProvider = SyncProvider(_syncService);
  }

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  void dispose() {
    _syncService.dispose();
    _dataProvider.dispose();
    _syncProvider.dispose();
    widget.localSync.dispose();
    AppLogger.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _dataProvider),
        ChangeNotifierProvider.value(value: _syncProvider),
        Provider.value(value: _syncService),
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

class _AppEntryPointState extends State<AppEntryPoint> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().loadUser();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final syncService = context.read<SyncService>();
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      syncService.pause();
    } else if (state == AppLifecycleState.resumed) {
      syncService.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.initialLoadComplete) {
          return Scaffold(
            backgroundColor: AppTheme.darkBg,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
              ),
            ),
          );
        }
        if (auth.isAuthenticated) {
          if (auth.onboardingCompleted) {
            return DashboardScreen(
              toggleTheme: widget.toggleTheme,
              themeMode: widget.themeMode,
            );
          }
          return OnboardingScreen(
            toggleTheme: widget.toggleTheme,
            themeMode: widget.themeMode,
          );
        }
        return LoginScreen(
          toggleTheme: widget.toggleTheme,
          themeMode: widget.themeMode,
        );
      },
    );
  }
}
