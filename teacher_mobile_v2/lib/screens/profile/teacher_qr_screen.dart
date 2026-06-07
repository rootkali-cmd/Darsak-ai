import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';

class TeacherQrScreen extends StatefulWidget {
  const TeacherQrScreen({super.key});

  @override
  State<TeacherQrScreen> createState() => _TeacherQrScreenState();
}

class _TeacherQrScreenState extends State<TeacherQrScreen> {
  String _code = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  Future<void> _loadCode() async {
    try {
      final resp = await ApiService().getMe();
      final teacher = resp['data'] is Map ? resp['data'] as Map<String, dynamic> : resp;
      _code = teacher['teacher_code']?.toString() ?? '';
      if (_code.isEmpty) {
        _error = 'لم يتم العثور على كود المدرس. يرجى التواصل مع الدعم.';
      }
    } on DioException {
      _error = 'تعذر الاتصال بالخادم. تأكد من اتصالك بالإنترنت.';
    } catch (_) {
      _error = 'حدث خطأ أثناء تحميل كود المدرس.';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _copyCode() {
    if (_code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ الكود'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: GlassTheme.glassAppBar('رمز QR للمدرس'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GlassTheme.indigo))
          : _error != null
              ? _buildError()
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: GlassTheme.glassCard,
                          child: QrImageView(
                            data: _code,
                            version: QrVersions.auto,
                            size: 220,
                            backgroundColor: Colors.white,
                            eyeStyle: QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: GlassTheme.indigo,
                            ),
                            dataModuleStyle: QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: GlassTheme.indigo,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          decoration: BoxDecoration(
                            color: GlassTheme.indigo.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: GlassTheme.indigo.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 16),
                              Text(
                                _code,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                  color: GlassTheme.indigo,
                                  letterSpacing: 4,
                                ),
                              ),
                              const SizedBox(width: 16),
                              GestureDetector(
                                onTap: _copyCode,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: GlassTheme.indigo.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.copy, color: GlassTheme.indigo, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _shareCode,
                            icon: const Icon(Icons.share),
                            label: const Text('مشاركة الكود'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GlassTheme.indigo,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'اطلب من طلابك مسح رمز QR للانضمام إلى مجموعاتك',
                          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.warning.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.qr_code_2, size: 56, color: AppTheme.warning),
            ),
            const SizedBox(height: 20),
            Text(
              _error!,
              style: const TextStyle(fontSize: 15, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _loadCode();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.indigo),
            ),
          ],
        ),
      ),
    );
  }
}
