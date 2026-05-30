import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screens/qr_scanner_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DarsakTeacherApp());
}

class DarsakTeacherApp extends StatelessWidget {
  const DarsakTeacherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DarsakAI Teacher',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // Logo
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [AppTheme.accent, AppTheme.accentLight]),
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                  child: const Icon(Icons.school, color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'DarsakAI Teacher',
                  style: TextStyle(color: AppTheme.darkTextPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'نظام إدارة الحضور بالـ QR',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ),
              const SizedBox(height: 60),
              // Main action
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner, size: 28),
                  label: const Text(
                    'فتح كاميرا المسح',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: AppTheme.accent,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Secondary actions
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.people,
                      label: 'الطلاب',
                      color: AppTheme.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.bar_chart,
                      label: 'التقارير',
                      color: AppTheme.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.settings,
                      label: 'الإعدادات',
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.help_outline,
                      label: 'المساعدة',
                      color: AppTheme.accentLight,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Footer
              Center(
                child: Text(
                  'v1.0.0 • للمدرسين بدون نظام PC',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ActionCard({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ],
      ),
    );
  }
}
