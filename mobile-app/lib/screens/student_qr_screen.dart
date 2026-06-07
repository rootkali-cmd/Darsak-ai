import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/auth_provider.dart';
import '../core/theme.dart';

class StudentQrScreen extends StatelessWidget {
  const StudentQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final student = auth.student;
    final studentCode = student?.code ?? '';
    final studentName = student?.fullName ?? 'طالب';
    
    final qrData = 'darsak://student/${student?.id ?? ''}/$studentCode';

    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text('كود الحضور'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.headerGradient(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF3B82F6)]),
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                      child: Center(
                        child: Text(
                          studentName.isNotEmpty ? studentName[0] : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studentName,
                            style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            studentCode,
                            style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 260,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  errorStateBuilder: (ctx, err) {
                    return const Center(
                      child: Text('خطأ في إنشاء QR', style: TextStyle(color: Colors.red)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigher(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.camera_alt, size: 20, color: AppTheme.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'ارفع QR Code أمام كاميرا المدرس',
                            style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.check_circle, size: 20, color: AppTheme.success),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'المسح تلقائي — لا حاجة للضغط على أي شيء',
                            style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.save_alt, size: 20, color: AppColors.textSecondary(context)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'يمكنك أخذ screenshot للحفظ',
                            style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: auth.isOnline ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: auth.isOnline ? AppTheme.success : AppTheme.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      auth.isOnline ? 'متصل — الحضور يُسجل فوراً' : 'غير متصل — سيتم التسجيل لاحقاً',
                      style: TextStyle(
                        color: auth.isOnline ? AppTheme.success : AppTheme.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
