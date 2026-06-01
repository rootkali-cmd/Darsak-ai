import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';

class TeacherCodeScreen extends StatefulWidget {
  const TeacherCodeScreen({super.key});

  @override
  State<TeacherCodeScreen> createState() => _TeacherCodeScreenState();
}

class _TeacherCodeScreenState extends State<TeacherCodeScreen> {
  String _code = '—';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  Future<void> _loadCode() async {
    try {
      final resp = await ApiService().dio.get('/auth/me');
      final data = resp.data;
      if (data is Map<String, dynamic>) {
        _code = data['teacher_code']?.toString() ?? '—';
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _copyCode() {
    if (_code != '—') {
      Clipboard.setData(ClipboardData(text: _code));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نسخ الكود'), backgroundColor: AppTheme.success),
      );
    }
  }

  void _shareCode() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ميزة المشاركة قيد التطوير'), backgroundColor: AppTheme.accent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('كود المدرس')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code, size: 80, color: AppTheme.accent),
                    const SizedBox(height: 24),
                    const Text(
                      'كود المدرس الخاص بك',
                      style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _code,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                          color: AppTheme.primary,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _copyCode,
                          icon: const Icon(Icons.copy),
                          label: const Text('نسخ الكود'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _shareCode,
                          icon: const Icon(Icons.share),
                          label: const Text('مشاركة'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'شارك هذا الكود مع طلابك للانضمام لمجموعاتك',
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
