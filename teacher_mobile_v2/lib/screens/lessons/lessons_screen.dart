import 'package:flutter/material.dart';

class LessonsScreen extends StatelessWidget {
  const LessonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: const Text('الدروس', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: const Icon(Icons.construction, size: 48, color: Color(0xFFF59E0B)),
              ),
              const SizedBox(height: 24),
              const Text(
                'قريباً إن شاء الله',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'هذه الميزة قيد التطوير حالياً. ستتوفر في التحديث القادم.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontFamily: 'Cairo',
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
