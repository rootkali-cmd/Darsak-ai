import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';

class TeacherQrScreen extends StatefulWidget {
  const TeacherQrScreen({super.key});

  @override
  State<TeacherQrScreen> createState() => _TeacherQrScreenState();
}

class _TeacherQrScreenState extends State<TeacherQrScreen> {
  String _code = '';
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
        _code = data['teacher_code']?.toString() ?? '';
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _shareCode() {
    if (_code.isEmpty) return;
    final user = context.read<AuthProvider>().user;
    final name = user?['full_name'] ?? 'المدرس';
    Share.share('انضم إلى مجموعاتي على درسك AI باستخدام كود المدرس: $_code\n'
        'المدرس: $name');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('رمز QR للمدرس')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _code.isNotEmpty
                          ? QrImageView(
                              data: _code,
                              version: QrVersions.auto,
                              size: 220,
                              backgroundColor: Colors.white,
                            )
                          : const SizedBox(
                              width: 220,
                              height: 220,
                              child: Center(
                                child: Text('لا يوجد كود', style: TextStyle(color: Colors.grey)),
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),
                    if (_code.isNotEmpty) ...[
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
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _shareCode,
                        icon: const Icon(Icons.share),
                        label: const Text('مشاركة الكود'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'اطلب من طلابك مسح رمز QR للانضمام إلى مجموعاتك',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppTheme.textMuted : AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
