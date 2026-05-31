import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _hasError = false;
  bool _needsLogin = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _controller.forward();
    _initialize();
  }

  Future<void> _initialize() async {
    _hasError = false;
    _needsLogin = false;
    if (mounted) setState(() {});

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final api = ApiService();
    bool awake = false;
    for (int i = 0; i < 5; i++) {
      awake = await api.ping();
      if (awake) break;
      if (!mounted) return;
      await Future.delayed(const Duration(seconds: 2));
    }

    if (!mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.checkAuth();

    if (!mounted) return;

    if (auth.isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else if (auth.hasToken) {
      // Has token but couldn't load user — keep trying, don't force login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      _needsLogin = true;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      body: Center(
        child: FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeIn),
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.accent, AppTheme.accentLight],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(Icons.school, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 24),
                Text(
                  'DarsakAI',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Teacher',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                if (!_needsLogin) ...[
                  SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(
                      backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
                if (_needsLogin) ...[
                  Icon(Icons.person, size: 48,
                    color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366)),
                  const SizedBox(height: 12),
                  Text(
                    'سجل دخولك للبدء',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('تسجيل الدخول'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
