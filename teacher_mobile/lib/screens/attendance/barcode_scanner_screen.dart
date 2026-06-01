import 'dart:async';
import 'dart:io';
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

enum ScanMode { choice, camera, manual, error }

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  ScanMode _mode = ScanMode.choice;

  CameraController? _camera;
  List<CameraDescription> _cameras = [];
  final BarcodeScanner _barcodeScanner = BarcodeScanner(
    formats: [BarcodeFormat.all],
  );
  bool _isProcessing = false;
  bool _cameraReady = false;
  String _errorMsg = '';
  Timer? _scanTimer;

  final List<Map<String, String>> _scannedStudents = [];
  final List<Map<String, dynamic>> _notifications = [];
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationTimer?.cancel();
    _scanTimer?.cancel();
    _disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed && _mode == ScanMode.camera) {
      _startCamera();
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

  Future<void> _startCamera() async {
    if (_camera != null) return;
    if (!mounted) return;
    setState(() {
      _mode = ScanMode.camera;
      _errorMsg = '';
    });

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showError('لا توجد كاميرا متاحة');
        return;
      }

      final cam = _cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras.first);

      _camera = CameraController(cam, ResolutionPreset.high,
          imageFormatGroup: ImageFormatGroup.yuv420,
          enableAudio: false);

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
    setState(() {
      _mode = ScanMode.error;
      _errorMsg = msg;
    });
    _disposeCamera();
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final input = _convertCameraImage(image);
      if (input == null) {
        _isProcessing = false;
        return;
      }

      final barcodes = await _barcodeScanner.processImage(input);

      for (final barcode in barcodes) {
        final raw = barcode.rawValue;
        if (raw == null || raw.isEmpty) continue;

        await _disposeCamera();
        if (mounted) processScan(raw);
        return;
      }
    } catch (_) {
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    return InputImage.fromBytes(
      bytes: _concatenatePlanes(image.planes),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    if (planes.isEmpty) return Uint8List(0);
    final bytes = planes.first.bytes;
    final bytesPerRow = planes.first.bytesPerRow;
    final height = planes.first.height ?? 0;
    if (bytes.length == bytesPerRow * height) return bytes;
    final total = planes.fold<int>(0, (s, p) => s + p.bytes.length);
    final result = Uint8List(total);
    var offset = 0;
    for (final plane in planes) {
      result.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }
    return result;
  }

  void processScan(String code) async {
    if (!mounted) return;

    try {
      await SoundEffects.playScan();
    } catch (_) {}

    final already = _scannedStudents.any((s) => s['code'] == code);
    if (already) {
      try {
        await SoundEffects.playWarning();
      } catch (_) {}
      _showNotification('تم المسح مسبقاً', 'الطالب: $code', AppTheme.warning);
      _restartScanner();
      return;
    }

    try {
      final result = await context
          .read<AttendanceProvider>()
          .markAttendanceByBarcode(code);

      final studentName = (result?['student_name'] ?? code).toString();
      _scannedStudents.add({'code': code, 'name': studentName});
      try {
        await SoundEffects.playSuccess();
      } catch (_) {}
      _showNotification('تم تسجيل الحضور', studentName, AppTheme.success);
    } catch (e) {
      _showNotification('فشل التسجيل', e.toString().replaceAll('Exception: ', ''), AppTheme.danger);
    }

    _restartScanner();
  }

  void _restartScanner() {
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted && _mode == ScanMode.camera) {
        _startCamera();
      } else if (mounted) {
        setState(() => _mode = ScanMode.choice);
      }
    });
  }

  void _showNotification(String title, String subtitle, Color color) {
    if (!mounted) return;
    _notifications.insert(0, {
      'title': title,
      'subtitle': subtitle,
      'color': color,
      'time': DateTime.now(),
    });
    if (_notifications.length > 3) _notifications.removeLast();
    setState(() {});
    _notificationTimer?.cancel();
    _notificationTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _notifications.clear();
        setState(() {});
      }
    });
  }

  void _showManualCodeDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إدخال كود الطالب'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'مثال: STU-1234567',
            labelText: 'الكود',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = controller.text.trim().toUpperCase();
              if (code.isNotEmpty) {
                Navigator.pop(ctx);
                processScan(code);
              }
            },
            child: const Text('تسجيل'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_mode) {
      case ScanMode.choice:
        return _buildChoiceScreen();
      case ScanMode.camera:
        if (!_cameraReady) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
          );
        }
        return _buildCameraScreen();
      case ScanMode.error:
        return _buildErrorScreen();
      case ScanMode.manual:
        return _buildChoiceScreen();
    }
  }

  Widget _buildChoiceScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('تسجيل الحضور', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code_scanner, size: 80, color: AppTheme.accent),
              const SizedBox(height: 24),
              const Text(
                'اختر طريقة تسجيل الحضور',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startCamera,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('مسح الباركود بالكاميرا',
                      style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showManualCodeDialog,
                  icon: const Icon(Icons.keyboard, color: Colors.white),
                  label: const Text('إدخال الكود يدوياً',
                      style: TextStyle(fontSize: 16, color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.textSecondary),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraScreen() {
    final size = MediaQuery.of(context).size;
    const overlayW = 280.0;
    const overlayH = 170.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_camera != null)
            Positioned.fill(child: CameraPreview(_camera!)),
          Positioned.fill(
            child: CustomPaint(
              painter: _ScannerOverlayPainter(
                borderColor: AppTheme.accent,
                overlayColor: Colors.black.withValues(alpha: 0.5),
                cutOutWidth: overlayW,
                cutOutHeight: overlayH,
                borderRadius: 8,
                borderLength: 30,
                borderWidth: 6,
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
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          _disposeCamera();
                          setState(() => _mode = ScanMode.choice);
                        },
                      ),
                      const Spacer(),
                      const Text(
                        'مسح الباركود',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white),
                        tooltip: 'إدخال يدوي',
                        onPressed: _showManualCodeDialog,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'وجّه الكاميرا نحو الباركود',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildNotifications(),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('خطأ في الكاميرا', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 64),
              const SizedBox(height: 16),
              const Text(
                'تعذر الوصول إلى الكاميرا',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMsg.length > 100 ? _errorMsg.substring(0, 100) : _errorMsg,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _startCamera,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                child: const Text('إعادة المحاولة'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _showManualCodeDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.textSecondary),
                ),
                child: const Text('إدخال الكود يدوياً'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotifications() {
    if (_notifications.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: kToolbarHeight + MediaQuery.of(context).padding.top + 60,
      left: 16,
      right: 16,
      child: Column(
        children: _notifications.map((n) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: (n['color'] as Color).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n['title'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            n['subtitle'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_scannedStudents.isNotEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8),
                        child: Text(
                          '${_scannedStudents.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final Color overlayColor;
  final double cutOutWidth;
  final double cutOutHeight;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;

  _ScannerOverlayPainter({
    required this.borderColor,
    required this.overlayColor,
    required this.cutOutWidth,
    required this.cutOutHeight,
    this.borderRadius = 8,
    this.borderLength = 30,
    this.borderWidth = 6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = overlayColor;

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: cutOutWidth,
        height: cutOutHeight,
      ),
      Radius.circular(borderRadius),
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
      ..strokeWidth = borderWidth;

    final cornerPath = Path();
    final r = rect.tlRadiusX;

    cornerPath.moveTo(rect.left, rect.top - 1);
    cornerPath.lineTo(rect.left + borderLength, rect.top - 1);
    cornerPath.moveTo(rect.left - 1, rect.top);
    cornerPath.lineTo(rect.left - 1, rect.top + borderLength);

    cornerPath.moveTo(rect.right - borderLength, rect.top - 1);
    cornerPath.lineTo(rect.right, rect.top - 1);
    cornerPath.moveTo(rect.right + 1, rect.top);
    cornerPath.lineTo(rect.right + 1, rect.top + borderLength);

    cornerPath.moveTo(rect.left, rect.bottom + 1);
    cornerPath.lineTo(rect.left + borderLength, rect.bottom + 1);
    cornerPath.moveTo(rect.left - 1, rect.bottom - borderLength);
    cornerPath.lineTo(rect.left - 1, rect.bottom);

    cornerPath.moveTo(rect.right - borderLength, rect.bottom + 1);
    cornerPath.lineTo(rect.right, rect.bottom + 1);
    cornerPath.moveTo(rect.right + 1, rect.bottom - borderLength);
    cornerPath.lineTo(rect.right + 1, rect.bottom);

    canvas.drawPath(cornerPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
