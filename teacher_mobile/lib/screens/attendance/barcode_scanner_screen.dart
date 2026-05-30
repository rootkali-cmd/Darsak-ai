import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../utils/sound_effects.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController? controller;
  bool isProcessing = false;
  final List<Map<String, String>> scannedStudents = [];
  final List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
      formats: [
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.ean8,
        BarcodeFormat.ean13,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.qrCode,
      ],
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
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
    await SoundEffects.playScan();

    final already = scannedStudents.any((s) => s['code'] == code);
    if (already) {
      await SoundEffects.playWarning();
      showNotification('تم المسح مسبقاً', 'الطالب: $code', Colors.orange);
      return;
    }

    setState(() => isProcessing = true);

    try {
      // Parse barcode: darsak://student/{id}/{code}
      int? studentId;
      if (code.contains('darsak://student/')) {
        final parts = code.split('/');
        if (parts.length >= 4) {
          studentId = int.tryParse(parts[3]);
        }
      }

      final provider = Provider.of<AttendanceProvider>(context, listen: false);
      final result = await provider.markAttendanceByBarcode(code);

      if (!mounted) return;

      final resultData = result;
      if (resultData != null) {
        final studentName = resultData['student']?['full_name'] ?? resultData['student']?['name'] ?? 'طالب';
        final status = resultData['status']?.toString().toLowerCase();

        // Play sound based on attendance status
        if (status == 'absent' || status == 'غائب') {
          await SoundEffects.playError();
          showNotification('الطالب غائب', studentName, Colors.red);
        } else if (status == 'late' || status == 'متأخر') {
          await SoundEffects.playWarning();
          showNotification('الطالب متأخر', studentName, Colors.orange);
        } else {
          await SoundEffects.playSuccess();
          showNotification('تم تسجيل الحضور', studentName, Colors.green);
        }

        setState(() {
          scannedStudents.insert(0, {'code': code, 'name': studentName});
          if (scannedStudents.length > 50) scannedStudents.removeLast();
          isProcessing = false;
        });
      } else {
        setState(() => isProcessing = false);
        await SoundEffects.playError();
        if (studentId == null) {
          showNotification('طالب غير معروف', 'لم يتم العثور على الطالب', Colors.red);
        } else {
          showNotification('خطأ', provider.error ?? 'فشل تسجيل الحضور', Colors.red);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isProcessing = false);
      await SoundEffects.playError();
      showNotification('خطأ', 'حدث خطأ أثناء المعالجة', Colors.red);
    }
  }

  void showNotification(String title, String subtitle, Color color) {
    final notification = {'title': title, 'subtitle': subtitle, 'color': color};
    setState(() {
      notifications.insert(0, notification);
      if (notifications.length > 4) notifications.removeLast();
    });

    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        setState(() => notifications.remove(notification));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (controller != null)
            MobileScanner(
              controller: controller!,
              onDetect: onDetect,
              errorBuilder: (context, error, child) => buildError(),
            ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      const Text(
                        'مسح الباركود',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.flash_on, color: Colors.white),
                        onPressed: () => controller?.toggleTorch(),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Center(
                  child: Container(
                    width: 280,
                    height: 160,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFdc2626).withValues(alpha: 0.6), width: 2),
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
                      const Icon(Icons.people, size: 18, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        '${scannedStudents.length} طالب',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 24),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isProcessing ? Colors.orange : Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isProcessing ? 'جاري المعالجة...' : 'جاهز للمسح',
                        style: TextStyle(
                          color: isProcessing ? Colors.orange : Colors.green,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: notifications.asMap().entries.map((entry) {
                final idx = entry.key;
                final n = entry.value;
                final opacity = (1.0 - (idx * 0.18)).clamp(0.3, 1.0);
                final scale = (1.0 - (idx * 0.04)).clamp(0.85, 1.0);
                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1a1a2e).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: (n['color'] as Color).withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: (n['color'] as Color).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.check_circle, size: 18, color: n['color'] as Color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  n['title'] as String,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  n['subtitle'] as String,
                                  style: const TextStyle(color: Color(0xFF6b7280), fontSize: 11),
                                ),
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

  Widget buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('تعذر الوصول للكاميرا', style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 8),
          Text('تحقق من إذن الكاميرا', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('رجوع'),
          ),
        ],
      ),
    );
  }
}
