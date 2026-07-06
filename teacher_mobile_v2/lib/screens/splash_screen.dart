import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/native_file_picker.dart';
import '../widgets/ai_thinking_loader.dart';
import 'home_screen.dart';
import 'onboarding/onboarding_screen.dart';
import 'landing/landing_page.dart';
import 'exams/ai_generate_exam_screen.dart';

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
    // Listen for init completion instead of polling
    late void Function() listener;
    listener = () {
      if (auth.isInitialized && mounted) {
        auth.removeListener(listener);
        _doNavigate(auth);
      }
    };
    auth.addListener(listener);
    // Safety timeout
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        auth.removeListener(listener);
        _doNavigate(auth);
      }
    });
  }

  void _doNavigate(AuthProvider auth) {
    if (!mounted) return;
    final sharedPdf = NativeFilePicker.getSharedPdf() as Future<String?>?;
    // Skip shared PDF on cold start, only check on app open from file
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
