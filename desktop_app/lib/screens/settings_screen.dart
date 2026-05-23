import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:barcode/barcode.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import '../providers/auth_provider.dart';
import '../providers/sync_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          Text(
            'الإعدادات',
            style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المعلومات الشخصية',
                    style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(label: 'الاسم', value: user?.fullName ?? '-', textMuted: textMuted, textPrimary: textPrimary),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'البريد الإلكتروني', value: user?.email ?? '-', textMuted: textMuted, textPrimary: textPrimary),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'كود المدرس', value: user?.teacherCode ?? '-', textMuted: textMuted, textPrimary: textPrimary),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'الدور', value: user?.role ?? '-', textMuted: textMuted, textPrimary: textPrimary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QR Code المعلم',
                    style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'امسح هذا الكود من تطبيق الطالب للربط بالمعلم',
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton.icon(
                      onPressed: () => _showTeacherQr(context),
                      icon: const Icon(Icons.qr_code, size: 18),
                      label: const Text('عرض QR Code'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المزامنة',
                    style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Consumer<SyncProvider>(
                    builder: (context, sync, _) {
                      return Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: sync.isOnline ? AppTheme.success : AppTheme.danger,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            sync.isOnline ? 'متصل' : 'غير متصل',
                            style: TextStyle(
                              color: sync.isOnline ? AppTheme.success : AppTheme.danger,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: ElevatedButton(
                              onPressed: sync.isOnline ? () => sync.syncNow() : null,
                              child: const Text('مزامنة الآن'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'حول التطبيق',
                    style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text('DarsakAI Desktop v1.0.0', style: TextStyle(color: textSecondary)),
                  Text('تطبيق سطح المكتب لإدارة الفصول والطلاب', style: TextStyle(color: textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTeacherQr(BuildContext context) {
    final api = ApiService();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FutureBuilder<Map<String, dynamic>>(
        future: api.generateQR(context.read<AuthProvider>().user?.id ?? ''),
        builder: (context, snapshot) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
          final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
          final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
          final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

          if (snapshot.connectionState == ConnectionState.waiting) {
            return AlertDialog(
              backgroundColor: surfaceColor,
              content: const SizedBox(
                width: 200, height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return AlertDialog(
              backgroundColor: surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor),
              ),
              title: const Text('خطأ'),
              content: const Text('فشل تحميل QR Code'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
              ],
            );
          }

          final data = snapshot.data!;
          final qrBase64 = data['qr_base64'] as String;
          final teacherCode = data['teacher_code'] as String;
          final teacherId = data['teacher_id'] as String;
          final qrPayload = 'darsak://teacher/$teacherId/$teacherCode';

          // Decode base64 to image bytes
          final base64Str = qrBase64.contains(',') ? qrBase64.split(',').last : qrBase64;
          final imageBytes = base64Decode(base64Str);

          return AlertDialog(
            backgroundColor: surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor),
            ),
            title: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accentLight]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(child: Icon(Icons.qr_code, color: Colors.white, size: 18)),
                ),
                const SizedBox(width: 12),
                Text('QR Code المعلم', style: TextStyle(color: textPrimary, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(imageBytes, width: 250, height: 250),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('كود المعلم:', style: TextStyle(color: textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      teacherCode,
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: AppTheme.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'اطبع الباركود وضعه في الفصل ليتمكن الطلاب من مسحه',
                            style: TextStyle(color: textSecondary, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.print, size: 16),
                  onPressed: () => _printTeacherQr(imageBytes, teacherCode),
                  label: const Text('طباعة'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _printTeacherQr(Uint8List imageBytes, String teacherCode) async {
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
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color textMuted;
  final Color textPrimary;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.textMuted,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: TextStyle(color: textMuted)),
        ),
        Text(value, style: TextStyle(color: textPrimary)),
      ],
    );
  }
}
