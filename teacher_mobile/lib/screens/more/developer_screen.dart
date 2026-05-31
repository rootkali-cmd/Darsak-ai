import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';

class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

  static const Color _whatsAppGreen = Color(0xFF25D366);
  static const Color _telegramBlue = Color(0xFF0088CC);

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('عن المطور')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.accent, AppTheme.accentLight],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ahmed Mahmoud Telly',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'المطور الرئيسي لتطبيق DarsakAI',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 260,
                child: OutlinedButton.icon(
                  onPressed: () => _openUrl('https://wa.me/201031524947'),
                  icon: const Icon(Icons.chat, color: _whatsAppGreen),
                  label: const Text(
                    'تواصل عبر WhatsApp',
                    style: TextStyle(color: _whatsAppGreen),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _whatsAppGreen),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 260,
                child: OutlinedButton.icon(
                  onPressed: () => _openUrl('https://t.me/G_M_L_M'),
                  icon: const Icon(Icons.send, color: _telegramBlue),
                  label: const Text(
                    'تواصل عبر Telegram',
                    style: TextStyle(color: _telegramBlue),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _telegramBlue),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? '---';
                  return Text(
                    'الإصدار $version',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
