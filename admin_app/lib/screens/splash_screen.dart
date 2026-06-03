import 'package:flutter/material.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('DarsakAI', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w300, color: Color(0xFFD4AF37), letterSpacing: 4)),
              SizedBox(height: 12),
              Text('Admin', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300, color: Color(0xFFD4AF37), letterSpacing: 8)),
            ],
          ),
        ),
      ),
    );
  }
}
