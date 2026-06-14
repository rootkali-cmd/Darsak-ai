import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../providers/data_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class QrScreen extends StatefulWidget {
  const QrScreen({super.key});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  Map<String, dynamic>? _qrData;
  bool _isLoading = false;
  String? _error;
  final GlobalKey _qrKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadQr();
  }

  static const String _cachedQrKey = 'cached_qr_data';

  void _loadQr() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // 1. Load cached QR instantly
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_cachedQrKey);
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final cached = jsonDecode(cachedJson) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _qrData = cached;
            _isLoading = false;
          });
        }
      } catch (_) {}
    }

    // 2. Background API call to refresh
    try {
      final teacherId = context.read<AuthProvider>().user?.id;
      if (teacherId == null || teacherId.isEmpty) {
        if (mounted && _qrData == null) setState(() => _isLoading = false);
        return;
      }
      final data = await context.read<DataProvider>().api.generateQR(teacherId).timeout(const Duration(seconds: 25));
      if (!mounted) return;
      // Cache fresh data
      await prefs.setString(_cachedQrKey, jsonEncode(data));
      setState(() {
        _qrData = data;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_qrData == null) {
        // No cache → show error with details
        final msg = e is DioException && e.response?.data?['detail'] != null
            ? 'خطأ: ${e.response!.data['detail']}'
            : 'تعذر تحميل QR Code. تأكد من اتصال الإنترنت واضغط لإعادة المحاولة.';
        setState(() {
          _error = msg;
          _isLoading = false;
        });
      } else {
        // Have cache → just stop loading silently
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _printQr() async {
    if (_qrData == null) return;
    final qrBase64 = _qrData!['qr_base64'] as String;
    final teacherCode = _qrData!['teacher_code'] as String;
    final base64Str = qrBase64.contains(',') ? qrBase64.split(',').last : qrBase64;
    final imageBytes = base64Decode(base64Str);

    await Printing.layoutPdf(
      onLayout: (format) async {
        final pdf = pw.Document();
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(80, 60, marginAll: 5),
            build: (ctx) => pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Image(pw.MemoryImage(imageBytes), width: 120, height: 120),
                  pw.SizedBox(height: 8),
                  pw.Text(teacherCode, style: pw.TextStyle(fontSize: 12)),
                  pw.Text('امسح لدخول الطالب', style: pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
          ),
        );
        return pdf.save();
      },
    );
  }

  Future<void> _saveAsImage() async {
    if (_qrData == null) return;
    try {
      final qrBase64 = _qrData!['qr_base64'] as String;
      final base64Str = qrBase64.contains(',') ? qrBase64.split(',').last : qrBase64;
      final imageBytes = base64Decode(base64Str);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/qr_teacher.png');
      await file.writeAsBytes(imageBytes);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم الحفظ في: ${file.path}'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    final user = context.watch<AuthProvider>().user;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: RepaintBoundary(
        key: _qrKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QR Code المعلم',
              style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'امسح هذا الكود من تطبيق الطالب للربط بالمعلم',
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            if (user != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accentLight]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            user.fullName.isNotEmpty ? user.fullName[0] : 'م',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.fullName, style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          if (user.teacherCode != null)
                            Text('كود المعلم: ${user.teacherCode}', style: TextStyle(color: textMuted, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            if (_isLoading)
              SizedBox(
                height: 400,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text('جاري تحميل QR Code...', style: TextStyle(color: textMuted)),
                    ],
                  ),
                ),
              )
            else if (_error != null)
              SizedBox(
                height: 400,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: AppTheme.danger.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: AppTheme.danger, fontSize: 16)),
                      const SizedBox(height: 16),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: ElevatedButton.icon(
                          onPressed: _loadQr,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_qrData != null)
              _buildQrContent(textPrimary, textSecondary, textMuted, surfaceColor, borderColor),
            if (_qrData != null) ...[
              const SizedBox(height: 24),
              Center(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: TextButton.icon(
                    onPressed: _loadQr,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('توليد رمز QR جديد'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQrContent(Color textPrimary, Color textSecondary, Color textMuted, Color surfaceColor, Color borderColor) {
    final qrBase64 = _qrData!['qr_base64'] as String;
    final teacherCode = _qrData!['teacher_code'] as String;
    final base64Str = qrBase64.contains(',') ? qrBase64.split(',').last : qrBase64;
    Uint8List? imageBytes;
    try {
      imageBytes = base64Decode(base64Str);
    } catch (_) {}

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: imageBytes != null
                    ? Image.memory(imageBytes, width: 280, height: 280)
                    : Container(
                        width: 280, height: 280,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(child: Icon(Icons.qr_code, size: 80, color: Colors.black26)),
                      ),
              ),
              const SizedBox(height: 24),
              Text('كود المعلم:', style: TextStyle(color: textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  teacherCode,
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppTheme.warning),
                  const SizedBox(width: 8),
                  Text(
                    'اطبع الباركود وضعه في الفصل ليتمكن الطلاب من مسحه',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: SizedBox(
                      width: 180,
                      child: ElevatedButton.icon(
                        onPressed: _printQr,
                        icon: const Icon(Icons.print, size: 18),
                        label: const Text('طباعة'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: SizedBox(
                      width: 180,
                      child: OutlinedButton.icon(
                        onPressed: _saveAsImage,
                        icon: const Icon(Icons.save_alt, size: 18),
                        label: const Text('حفظ كصورة'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accent,
                          side: const BorderSide(color: AppTheme.accent),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
