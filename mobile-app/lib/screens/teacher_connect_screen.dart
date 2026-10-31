import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import 'login_screen.dart';

class TeacherConnectScreen extends StatefulWidget {
  const TeacherConnectScreen({super.key});

  @override
  State<TeacherConnectScreen> createState() => _TeacherConnectScreenState();
}

class _TeacherConnectScreenState extends State<TeacherConnectScreen>
    with TickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _api = ApiService();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _parsingBarcode = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800), vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic));
    _fadeController.forward();
    _codeController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (_parsingBarcode) return;
    final text = _codeController.text;
    if (text.endsWith('\n')) {
      _parsingBarcode = true;
      final clean = text.trim();
      String? code;
      if (clean.startsWith('darsak://teacher/')) {
        code = _extractTeacherCode(clean);
      } else if (clean.startsWith('TCH-') && clean.length <= 20) {
        code = clean;
      } else { code = clean; }
      if (code != null && code.isNotEmpty) {
        _codeController.text = code;
        _codeController.selection = TextSelection.fromPosition(TextPosition(offset: code.length));
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _connect(code: code);
        });
      }
      _parsingBarcode = false;
    }
  }

  String? _extractTeacherCode(String raw) {
    try {
      final clean = raw.trim().split('\n').first.trim();
      if (clean.startsWith('darsak://teacher/')) {
        final parts = clean.split('/');
        if (parts.length >= 4) { final code = parts[3]; if (code.isNotEmpty) return code; }
      }
      if (clean.length <= 20 && RegExp(r'^TCH[-:][A-Z0-9]+$').hasMatch(clean)) {
        return clean.replaceAll(':', '-');
      }
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _codeController.removeListener(_onInputChanged);
    _codeController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _connect({String? code}) async {
    final teacherCode = (code ?? _codeController.text).trim();
    if (teacherCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('أدخل كود المعلم'), backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ); return;
    }
    setState(() => _isLoading = true);
    try {
      final result = await _api.verifyTeacher(teacherCode);
      if (!mounted) return;
      final teacherCodeStr = result['teacher_code']?.toString() ?? '';
      final teacherNameStr = result['teacher_name']?.toString() ?? '';
      await _storage.write(key: AppConstants.storageKeyTeacherCode, value: teacherCodeStr);
      await _storage.write(key: AppConstants.storageKeyTeacherName, value: teacherNameStr);
      Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => LoginScreen(teacherCode: teacherCodeStr)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('كود المعلم غير صحيح'), backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _openScanner() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const QrScannerScreen())).then((teacherCode) {
      if (teacherCode != null && teacherCode is String) {
        _codeController.text = teacherCode;
        _connect(code: teacherCode);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF3B82F6)]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 24),
                    Text('الاتصال بالمعلم', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('امسح باركود المعلم أو أدخل الكود يدوياً', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14)),
                    const SizedBox(height: 40),
                    TextFormField(
                      controller: _codeController, textDirection: TextDirection.ltr, textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textPrimary(context), fontSize: 18, letterSpacing: 2),
                      decoration: InputDecoration(
                        labelText: 'كود المعلم', hintText: 'TCH-XXXXXX',
                        hintStyle: TextStyle(color: AppColors.textSecondary(context)),
                        prefixIcon: const Icon(Icons.person, color: AppTheme.accent),
                        filled: true, fillColor: AppColors.inputFill(context),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.accent)),
                      ),
                      textInputAction: TextInputAction.done, onFieldSubmitted: (_) => _connect(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _openScanner,
                        icon: const Icon(Icons.qr_code_scanner, size: 20),
                        label: const Text('مسح QR Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceHigher(context),
                          foregroundColor: AppColors.textPrimary(context),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border(context))),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _connect(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent, disabledBackgroundColor: AppTheme.accent.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('اتصال', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('تسجيل دخول الطالب مباشرة'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary(context)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: [BarcodeFormat.qrCode, BarcodeFormat.code128],
  );

  bool _found = false;
  bool _cameraReady = false;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _cameraReady = true;
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_found) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;

      _found = true;
      final teacherCode = _extractCodeFromRaw(raw);
      if (teacherCode != null) {
        Navigator.pop(context, teacherCode);
      } else {
        _found = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('باركود غير صالح'), backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      return;
    }
  }

  String? _extractCodeFromRaw(String raw) {
    final clean = raw.trim();
    if (clean.startsWith('darsak://teacher/')) {
      final parts = clean.split('/');
      if (parts.length >= 4) { final code = parts[3]; if (code.isNotEmpty) return code; }
    }
    if (clean.length <= 20 && RegExp(r'^TCH[-:][A-Z0-9]+$').hasMatch(clean)) {
      return clean.replaceAll(':', '-');
    }
    if (clean.length <= 20 && RegExp(r'^[A-Z0-9\-]+$').hasMatch(clean)) {
      return clean;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('مسح QR Code'),
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              if (mounted) {
                setState(() {
                  _errorMsg = 'تعذر تشغيل الكاميرا: ${error.errorCode.name}';
                  _cameraReady = false;
                });
              }
              return const SizedBox.shrink();
            },
          ),
          if (_cameraReady)
            Positioned.fill(
              child: Container(
                alignment: Alignment.center,
                child: Container(
                  width: 250, height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.accent, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          if (!_cameraReady && _errorMsg.isEmpty)
            const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
          if (_errorMsg.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('تعذر الوصول إلى الكاميرا', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_errorMsg, style: TextStyle(color: Colors.grey[400], fontSize: 14), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() { _errorMsg = ''; _cameraReady = false; });
                        _scannerController.start();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                      child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.grey)),
                      child: const Text('رجوع'),
                    ),
                  ],
                ),
              ),
            ),
          if (_cameraReady)
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: Center(
                child: Text('وجّه الكاميرا نحو الباركود',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }
}
