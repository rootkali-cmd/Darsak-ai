import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/ai_thinking_loader.dart';
import 'home_screen.dart';
import 'onboarding/onboarding_screen.dart';
import 'landing/landing_page.dart';
import 'maintenance_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigate());
  }

  Future<void> _navigate() async {
    final auth = context.read<AuthProvider>();
    if (auth.isInitialized) {
      _doNavigate(auth);
      return;
    }
    late void Function() listener;
    listener = () {
      if (auth.isInitialized && mounted) {
        auth.removeListener(listener);
        _doNavigate(auth);
      }
    };
    auth.addListener(listener);
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        auth.removeListener(listener);
        _doNavigate(auth);
      }
    });
  }

  void _doNavigate(AuthProvider auth) {
    if (!mounted) return;
    // Check maintenance status first
    ApiService().dio.get('/app-status').then((resp) async {
      if (!mounted) return;
      final data = resp.data is Map ? Map<String, dynamic>.from(resp.data) : <String, dynamic>{};
      final underMaintenance = data['under_maintenance'] == true;
      final maintenanceTeacher = data['maintenance_teacher'] == true;
      if (underMaintenance && maintenanceTeacher) {
        final message = data['message']?.toString() ?? '';
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MaintenanceScreen(message: message)));
        return;
      }
      _navigateAfterCheck(auth);
    }).catchError((_) {
      if (mounted) _navigateAfterCheck(auth);
    });
  }

  void _navigateAfterCheck(AuthProvider auth) {
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      if (!auth.isAuthenticated) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LandingPage()));
        return;
      }
      if (auth.needsOnboarding) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
        return;
      }
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0a0a1a),
      body: AIThinkingLoader(),
    );
  }
}
