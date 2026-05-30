import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'عام',
            style: TextStyle(color: Color(0xFF6b7280), fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            color: const Color(0xFF1a1a2e),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dark_mode, color: Colors.white),
                  title: const Text('الوضع الداكن', style: TextStyle(color: Colors.white)),
                  trailing: Switch(
                    value: true,
                    onChanged: (v) {},
                    activeThumbColor: const Color(0xFFdc2626),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF2a2a3e)),
                ListTile(
                  leading: const Icon(Icons.notifications, color: Colors.white),
                  title: const Text('الإشعارات', style: TextStyle(color: Colors.white)),
                  trailing: Switch(
                    value: true,
                    onChanged: (v) {},
                    activeThumbColor: const Color(0xFFdc2626),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'حول التطبيق',
            style: TextStyle(color: Color(0xFF6b7280), fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            color: const Color(0xFF1a1a2e),
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info, color: Colors.white),
                  title: Text('الإصدار', style: TextStyle(color: Colors.white)),
                  trailing: Text('1.0.0', style: TextStyle(color: Color(0xFF6b7280))),
                ),
                const Divider(height: 1, color: Color(0xFF2a2a3e)),
                ListTile(
                  leading: const Icon(Icons.language, color: Colors.white),
                  title: const Text('اللغة', style: TextStyle(color: Colors.white)),
                  trailing: const Text('العربية', style: TextStyle(color: Color(0xFF6b7280))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
