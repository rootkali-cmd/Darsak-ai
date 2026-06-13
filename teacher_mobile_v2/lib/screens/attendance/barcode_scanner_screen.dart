import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../utils/sound_effects.dart';
import '../../core/app_theme.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  List<CameraDescription> _cameras = [];
  final BarcodeScanner _barcodeScanner = BarcodeScanner(
    formats: [BarcodeFormat.qrCode, BarcodeFormat.code128, BarcodeFormat.code39, BarcodeFormat.ean13],
  );
  bool _isProcessing = false;
  bool _cameraReady = false;
  String _errorMsg = '';
  bool _scanned = false;
  DateTime _lastProcessed = DateTime.now();

  final List<Map<String, String>> _scannedStudents = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _disposeCamera() async {
    try {
      await _camera?.stopImageStream();
    } catch (_) {}
    try {
      await _camera?.dispose();
    } catch (_) {}
    _camera = null;
    if (mounted) setState(() => _cameraReady = false);
  }

  Future<void> _initCamera() async {
    if (_camera != null) return;
    if (!mounted) return;

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) { _showError('لا توجد كاميرا متاحة'); return; }

      final cam = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _camera = CameraController(
        cam,
        ResolutionPreset.medium,
        imageFormatGroup: ImageFormatGroup.yuv420,
        enableAudio: false,
      );

      await _camera!.initialize();
      if (!mounted) return;

      await _camera!.startImageStream(_processFrame);
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      _showError('تعذر تشغيل الكاميرا: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() { _errorMsg = msg; _cameraReady = false; });
    _disposeCamera();
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing || _scanned) return;

    final now = DateTime.now();
    if (now.difference(_lastProcessed).inMilliseconds < 200) return;
    _lastProcessed = now;

    _isProcessing = true;
    try {
      final input = _buildInputImage(image);
      if (input == null) { _isProcessing = false; return; }

      final barcodes = await _barcodeScanner.processImage(input);

      if (barcodes.isNotEmpty && !_scanned) {
        for (final barcode in barcodes) {
          final raw = barcode.rawValue;
          if (raw == null || raw.isEmpty) continue;
          _scanned = true;
          await _disposeCamera();
          if (mounted) _processScan(raw);
          return;
        }
      }
    } catch (_) {
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _processScan(String code) async {
    if (!mounted) return;

    try { await SoundEffects.playScan(); } catch (_) {}

    final already = _scannedStudents.any((s) => s['code'] == code);
    if (already) {
      try { await SoundEffects.playWarning(); } catch (_) {}
      _showSnackBar('تم المسح مسبقاً: $code', AppTheme.warning);
      _resetScanner();
      return;
    }

    try {
      final result = await context
          .read<AttendanceProvider>()
          .markAttendanceByBarcode(code);

      final studentName = (result?['student_name'] ?? code).toString();

      setState(() {
        _scannedStudents.insert(0, {'code': code, 'name': studentName});
        if (_scannedStudents.length > 4) _scannedStudents.removeLast();
      });

      try { await SoundEffects.playSuccess(); } catch (_) {}
      _showSnackBar('✓ $studentName - حاضر', AppTheme.success);
    } catch (e) {
      try { await SoundEffects.playWarning(); } catch (_) {}
      _showSnackBar('✗ ${e.toString().replaceAll('Exception: ', '')}', AppTheme.danger);
    }

    _resetScanner();
  }

  void _resetScanner() {
    _isProcessing = false;
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) { _scanned = false; _initCamera(); }
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
                _disposeCamera();
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
          if (_cameraReady)
            IconButton(
              icon: const Icon(Icons.flashlight_on, color: Colors.white),
              tooltip: 'فلاش',
              onPressed: () {
                try { _camera?.setFlashMode(FlashMode.torch); } catch (_) {}
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_cameraReady && _camera != null)
            Positioned.fill(child: CameraPreview(_camera!)),
          if (_cameraReady)
            Positioned.fill(
              child: CustomPaint(
                painter: _ScannerOverlayPainter(
                  borderColor: AppTheme.accent,
                  overlayColor: Colors.black.withValues(alpha: 0.5),
                  cutOutWidth: 280,
                  cutOutHeight: 170,
                ),
              ),
            ),
          if (!_cameraReady && _errorMsg.isEmpty)
            const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
          if (_errorMsg.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white),
                    const SizedBox(height: 16),
                    const Text('تعذر الوصول إلى الكاميرا', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(_errorMsg, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () { _disposeCamera(); _initCamera(); },
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
            ),
          if (_cameraReady)
            Positioned(
              bottom: 180, left: 0, right: 0,
              child: Center(
                child: Text('وجّه الكاميرا نحو الباركود',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
              ),
            ),
          if (_scannedStudents.isNotEmpty)
            Positioned(
              bottom: 0, left: 0, right: 0,
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
                          Expanded(child: Text(s['name'] ?? s['code'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis)),
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

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(rect),
      ),
      paint,
    );

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    const cornerLength = 30.0;
    final cornerPath = Path();

    cornerPath.moveTo(rect.left, rect.top + cornerLength);
    cornerPath.lineTo(rect.left, rect.top);
    cornerPath.lineTo(rect.left + cornerLength, rect.top);

    cornerPath.moveTo(rect.right - cornerLength, rect.top);
    cornerPath.lineTo(rect.right, rect.top);
    cornerPath.lineTo(rect.right, rect.top + cornerLength);

    cornerPath.moveTo(rect.left, rect.bottom - cornerLength);
    cornerPath.lineTo(rect.left, rect.bottom);
    cornerPath.lineTo(rect.left + cornerLength, rect.bottom);

    cornerPath.moveTo(rect.right - cornerLength, rect.bottom);
    cornerPath.lineTo(rect.right, rect.bottom);
    cornerPath.lineTo(rect.right, rect.bottom - cornerLength);

    canvas.drawPath(cornerPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
