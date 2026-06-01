import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../utils/sound_effects.dart';
import '../../core/app_theme.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController? controller;
  bool isProcessing = false;
  bool cameraReady = false;
  bool permissionDenied = false;
  final List<Map<String, String>> scannedStudents = [];
  final List<Map<String, dynamic>> notifications = [];
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    controller?.dispose();
    super.dispose();
  }

  Future<void> _initScanner() async {
    try {
      controller = MobileScannerController();
      if (mounted) setState(() => cameraReady = true);
    } catch (e) {
      if (mounted) _tryFrontCameraFallback();
    }
  }

  Future<void> _tryFrontCameraFallback() async {
    try {
      controller?.dispose();
      controller = MobileScannerController(facing: CameraFacing.front);
      if (mounted) setState(() => cameraReady = true);
    } catch (e) {
      if (mounted) {
        setState(() => permissionDenied = true);
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.danger),
    );
  }

  void onDetect(BarcodeCapture capture) {
    if (isProcessing) return;
    final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    if (barcode == null) return;
    final raw = barcode.rawValue;
    if (raw == null || raw.isEmpty) return;
    processScan(raw);
  }

  Future<void> processScan(String code) async {
    if (!mounted) return;

    try { await SoundEffects.playScan(); } catch (_) {}

    final already = scannedStudents.any((s) => s['code'] == code);
    if (already) {
      try { await SoundEffects.playWarning(); } catch (_) {}
      _showNotification('تم المسح مسبقاً', 'الطالب: $code', AppTheme.warning);
      return;
    }

    if (!mounted) return;
    setState(() => isProcessing = true);

    try {
      final provider = Provider.of<AttendanceProvider>(context, listen: false);
      final result = await provider.markAttendanceByBarcode(code)
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (result != null) {
        final studentName = result['student']?['full_name'] ?? result['student']?['name'] ?? 'طالب';
        final status = result['status']?.toString().toLowerCase();

        if (status == 'absent' || status == 'غائب') {
          try { await SoundEffects.playError(); } catch (_) {}
          _showNotification('الطالب غائب', studentName, AppTheme.danger);
        } else if (status == 'late' || status == 'متأخر') {
          try { await SoundEffects.playWarning(); } catch (_) {}
          _showNotification('الطالب متأخر', studentName, AppTheme.warning);
        } else {
          try { await SoundEffects.playSuccess(); } catch (_) {}
          _showNotification('تم تسجيل الحضور', studentName, AppTheme.success);
        }

        setState(() {
          scannedStudents.insert(0, {'code': code, 'name': studentName});
          if (scannedStudents.length > 50) scannedStudents.removeLast();
          isProcessing = false;
        });
      } else {
        setState(() => isProcessing = false);
        try { await SoundEffects.playError(); } catch (_) {}
        _showNotification('خطأ', provider.error ?? 'فشل تسجيل الحضور', AppTheme.danger);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isProcessing = false);
      try { await SoundEffects.playError(); } catch (_) {}
      final errStr = e.toString();
      _showNotification('خطأ', errStr.length > 80 ? errStr.substring(0, 80) : errStr, AppTheme.danger);
    }
  }

  void _showNotification(String title, String subtitle, Color color) {
    final notification = {'title': title, 'subtitle': subtitle, 'color': color};
    setState(() {
      notifications.insert(0, notification);
      if (notifications.length > 4) notifications.removeLast();
    });

    _notificationTimer?.cancel();
    _notificationTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => notifications.remove(notification));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (permissionDenied) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt_outlined, size: 64, color: AppTheme.textMuted),
                  const SizedBox(height: 24),
                  const Text(
                    'الكاميرا غير متاحة',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'الرجاء السماح للكاميرا من إعدادات الجهاز',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => permissionDenied = false);
                      _initScanner();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                    child: const Text('إعادة المحاولة'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('رجوع'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!cameraReady) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (controller != null)
            MobileScanner(
              controller: controller!,
              onDetect: onDetect,
              errorBuilder: (context, error, child) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_outlined, size: 64, color: AppTheme.textMuted),
                      const SizedBox(height: 16),
                      const Text(
                        'تعذر الوصول إلى الكاميرا',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'خطأ: ${error.toString().length > 60 ? error.toString().substring(0, 60) : error}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _IconBtn(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                      const Spacer(),
                      const Text(
                        'مسح الباركود',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      _IconBtn(icon: Icons.flash_on, onTap: () => controller?.toggleTorch()),
                    ],
                  ),
                ),
                const Spacer(),
                Center(
                  child: Container(
                    width: 280,
                    height: 160,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.6), width: 2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people, size: 18, color: AppTheme.success),
                      const SizedBox(width: 8),
                      Text(
                        '${scannedStudents.length} طالب',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 24),
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isProcessing ? AppTheme.warning : AppTheme.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isProcessing ? 'جاري المعالجة...' : 'جاهز للمسح',
                        style: TextStyle(
                          color: isProcessing ? AppTheme.warning : AppTheme.success, fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 100, left: 0, right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: notifications.asMap().entries.map((entry) {
                final idx = entry.key;
                final n = entry.value;
                final opacity = (1.0 - (idx * 0.18)).clamp(0.3, 1.0);
                final scale = (1.0 - (idx * 0.04)).clamp(0.85, 1.0);
                final color = n['color'] as Color;
                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.check_circle, size: 18, color: color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(n['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                Text(n['subtitle'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
