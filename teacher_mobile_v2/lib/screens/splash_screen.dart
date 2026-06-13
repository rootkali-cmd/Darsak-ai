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
    final start = DateTime.now();
    while (!auth.isInitialized && DateTime.now().difference(start).inSeconds < 5) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;

    final sharedPdf = await NativeFilePicker.getSharedPdf();

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    if (!auth.isAuthenticated) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LandingPage()));
      return;
    }

    if (auth.needsOnboarding) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
      return;
    }

    if (sharedPdf != null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => AiGenerateExamScreen(initialFilePath: sharedPdf),
      ));
      return;
    }

    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0a0a1a),
      body: AIThinkingLoader(),
    );
  }
}
