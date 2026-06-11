import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
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
  MobileScannerController? _controller;
  bool _isProcessing = false;
  bool _scanned = false;
  final List<Map<String, String>> _scannedStudents = [];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted || status.isLimited) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _scanned) return;
    
    final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    if (barcode == null || barcode.rawValue == null || barcode.rawValue!.isEmpty) return;

    _isProcessing = true;
    final code = barcode.rawValue!.trim();
    
    // Stop camera immediately to prevent duplicate scans
    _controller?.stop();
    _scanned = true;
    
    _processScan(code);
  }

  Future<void> _processScan(String code) async {
    if (!mounted) return;

    try {
      await SoundEffects.playScan();
    } catch (_) {}

    final already = _scannedStudents.any((s) => s['code'] == code);
    if (already) {
      try {
        await SoundEffects.playWarning();
      } catch (_) {}
      _showSnackBar('تم المسح مسبقاً: $code', AppTheme.warning);
      _resetScanner();
      return;
    }

    try {
      final result = await context
          .read<AttendanceProvider>()
          .markAttendanceByBarcode(code);

      final studentName = (result?['student_name'] ?? code).toString();
      final status = result?['status']?.toString() ?? 'present';

      setState(() {
        _scannedStudents.insert(0, {'code': code, 'name': studentName, 'status': status});
        if (_scannedStudents.length > 4) _scannedStudents.removeLast();
      });

      try {
        await SoundEffects.playSuccess();
      } catch (_) {}
      _showSnackBar('✓ $studentName - حاضر', AppTheme.success);
    } catch (e) {
      try {
        await SoundEffects.playError();
      } catch (_) {}
      _showSnackBar('✗ خطأ: ${e.toString().replaceAll('Exception: ', '')}', AppTheme.danger);
    }

    _resetScanner();
  }

  void _resetScanner() {
    _isProcessing = false;
    // Resume scanning after 1.5 seconds
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _scanned = false;
        _controller?.start();
      }
    });
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: color.withValues(alpha: 0.9),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showManualCodeDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('إدخال كود الطالب', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'مثال: STU-1234567',
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
            labelText: 'الكود',
            labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () {
              final code = controller.text.trim().toUpperCase();
              if (code.isNotEmpty) {
                Navigator.pop(ctx);
                _scanned = true;
                _controller?.stop();
                _processScan(code);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            child: const Text('تسجيل'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('مسح الباركود', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'إدخال يدوي',
            onPressed: _showManualCodeDialog,
          ),
          IconButton(
            icon: const Icon(Icons.flashlight_on, color: Colors.white),
            tooltip: 'فلاش',
            onPressed: () => _controller?.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera preview
          MobileScanner(
            controller: _controller!,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white),
                      const SizedBox(height: 16),
                      const Text('تعذر الوصول إلى الكاميرا', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(error.errorDetails?.message ?? 'خطأ غير معروف', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12), textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () async {
                          await Permission.camera.request();
                          _scanned = false;
                          _controller?.start();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                        child: const Text('إعادة المحاولة'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _showManualCodeDialog,
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0xFF64748B))),
                        child: const Text('إدخال الكود يدوياً'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Scanner overlay
          Positioned.fill(
            child: CustomPaint(
              painter: _ScannerOverlayPainter(
                borderColor: AppTheme.accent,
                overlayColor: Colors.black.withValues(alpha: 0.5),
                cutOutWidth: 280.0,
                cutOutHeight: 170.0,
              ),
            ),
          ),
          // Instruction text
          Positioned(
            bottom: 180,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'وجّه الكاميرا نحو الباركود',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
              ),
            ),
          ),
          // Recent scanned students
          if (_scannedStudents.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('آخر ${_scannedStudents.length} طلاب', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
                    const SizedBox(height: 6),
                    ..._scannedStudents.take(4).map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppTheme.success, size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(s['name'] ?? s['code'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final Color overlayColor;
  final double cutOutWidth;
  final double cutOutHeight;

  _ScannerOverlayPainter({
    required this.borderColor,
    required this.overlayColor,
    required this.cutOutWidth,
    required this.cutOutHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = overlayColor;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: cutOutWidth, height: cutOutHeight),
      const Radius.circular(12),
    );

    // Draw overlay with cutout
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(rect),
      ),
      paint,
    );

    // Draw corner borders
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    const cornerLength = 30.0;
    final cornerPath = Path();

    // Top-left
    cornerPath.moveTo(rect.left, rect.top + cornerLength);
    cornerPath.lineTo(rect.left, rect.top);
    cornerPath.lineTo(rect.left + cornerLength, rect.top);

    // Top-right
    cornerPath.moveTo(rect.right - cornerLength, rect.top);
    cornerPath.lineTo(rect.right, rect.top);
    cornerPath.lineTo(rect.right, rect.top + cornerLength);

    // Bottom-left
    cornerPath.moveTo(rect.left, rect.bottom - cornerLength);
    cornerPath.lineTo(rect.left, rect.bottom);
    cornerPath.lineTo(rect.left + cornerLength, rect.bottom);

    // Bottom-right
    cornerPath.moveTo(rect.right - cornerLength, rect.bottom);
    cornerPath.lineTo(rect.right, rect.bottom);
    cornerPath.lineTo(rect.right, rect.bottom - cornerLength);

    canvas.drawPath(cornerPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
