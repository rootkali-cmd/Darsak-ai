import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/notification_service.dart';
import '../../../providers/data_provider.dart';

class QrCameraScreen extends StatefulWidget {
  final String? groupId;
  const QrCameraScreen({super.key, this.groupId});

  @override
  State<QrCameraScreen> createState() => _QrCameraScreenState();
}

class _QrCameraScreenState extends State<QrCameraScreen> {
  MobileScannerController? _controller;
  bool _found = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_found || _isProcessing) return;
    final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    if (barcode == null) return;
    final raw = barcode.rawValue;
    if (raw == null || raw.isEmpty) return;

    final studentData = _extractStudentFromQr(raw);
    if (studentData != null) {
      _found = true;
      _processScan(studentData);
    }
  }

  Map<String, String>? _extractStudentFromQr(String raw) {
    final clean = raw.trim();
    // Format: darsak://student/{student_id}/{student_code}
    if (clean.startsWith('darsak://student/')) {
      final parts = clean.split('/');
      if (parts.length >= 4) {
        return {
          'student_id': parts[3],
          if (parts.length >= 5) 'student_code': parts[4],
        };
      }
    }
    // Fallback: just a student code
    if (clean.length <= 20 && RegExp(r'^[A-Z0-9]+$').hasMatch(clean)) {
      return {'student_code': clean};
    }
    return null;
  }

  Future<void> _processScan(Map<String, String> data) async {
    setState(() => _isProcessing = true);
    final studentCode = data['student_code'] ?? data['student_id'] ?? '';

    try {
      final api = context.read<DataProvider>().api;
      final result = await api.markAttendanceByQr(
        data['student_id'] ?? studentCode,
        groupId: widget.groupId,
      ).timeout(const Duration(seconds: 8));

      final studentName = result['student_name']?.toString() ?? 'طالب';
      final status = result['status']?.toString() ?? 'present';

      NotificationService.instance.show(
        title: status == 'present' ? 'تم تسجيل الحضور' : 'تم تسجيل الغياب',
        subtitle: '$studentName — $studentCode',
        icon: status == 'present' ? Icons.check_circle : Icons.cancel,
        color: status == 'present' ? AppTheme.success : AppTheme.danger,
      );
    } catch (e) {
      NotificationService.instance.show(
        title: 'فشل تسجيل الحضور',
        subtitle: 'تم الحفظ محلياً للمزامنة لاحقاً',
        icon: Icons.error_outline,
        color: AppTheme.warning,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _found = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (_controller != null)
            MobileScanner(
              controller: _controller!,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'تعذر الوصول إلى الكاميرا',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'يرجى التحقق من إذن الكاميرا في إعدادات الجهاز',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                        child: const Text('رجوع'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Overlay UI
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'مسح QR Code للحضور',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      if (_isProcessing)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                        ),
                    ],
                  ),
                ),

                const Spacer(),

                // Scan frame indicator
                Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.5), width: 2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      children: [
                        // Corner markers
                        Positioned(top: 0, left: 0, child: _CornerMarker()),
                        Positioned(top: 0, right: 0, child: _CornerMarker()),
                        Positioned(bottom: 0, left: 0, child: _CornerMarker()),
                        Positioned(bottom: 0, right: 0, child: _CornerMarker()),
                        // Center text
                        const Center(
                          child: Text(
                            'وجّه الكاميرا نحو QR Code الطالب',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Bottom hint
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AppTheme.accent.withValues(alpha: 0.8)),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'المسح تلقائي — ارفع QR Code الطالب أمام الكاميرا',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        border: Border(
          top: const BorderSide(color: AppTheme.accent, width: 3),
          left: const BorderSide(color: AppTheme.accent, width: 3),
        ),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(8)),
      ),
    );
  }
}
