import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/data_provider.dart';

class TeacherCodeScreen extends StatefulWidget {
  const TeacherCodeScreen({super.key});

  @override
  State<TeacherCodeScreen> createState() => _TeacherCodeScreenState();
}

class _TeacherCodeScreenState extends State<TeacherCodeScreen> {
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
      final api = context.read<DataProvider>().api;
      final resp = await api.getMe();
      final teacher = resp['data'] is Map ? resp['data'] as Map<String, dynamic> : resp;
      _code = teacher['teacher_code']?.toString() ?? '';
      if (_code.isEmpty) _error = 'لم يتم العثور على كود المدرس.';
    } catch (_) {
      _error = 'تعذر تحميل الكود. تأكد من اتصالك بالإنترنت.';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _copyCode() {
    if (_code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ الكود'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.warning.withValues(alpha: 0.1)),
                        child: const Icon(Icons.error_outline, size: 56, color: AppTheme.warning),
                      ),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () { setState(() { _loading = true; _error = null; }); _loadCode(); },
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('كود المدرس', style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
                          child: QrImageView(
                            data: _code,
                            version: QrVersions.auto,
                            size: 200,
                            backgroundColor: Colors.white,
                            eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: AppTheme.accent),
                            dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppTheme.accent),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_code, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.accent, letterSpacing: 3)),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: _copyCode,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.copy, color: AppTheme.accent, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('شارك هذا الكود مع طلابك للانضمام لمجموعاتك', style: TextStyle(fontSize: 13, color: textSecondary), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
    );
  }
}
